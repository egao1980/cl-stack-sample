;;;; An ai-agent-protocol agent whose one tool is this project's library.
;;;; Live: ANTHROPIC_API_KEY set, then (cl-stack-sample/agent:ask "…").
;;;; Offline: pass any llm-protocol backend, e.g. the mock one (see the tests).

(defpackage #:cl-stack-sample/agent
  (:use #:cl #:ai-agent-protocol #:llm-protocol)
  (:export #:+instructions+
           #:make-duration-tool
           #:make-duration-agent
           #:use-async-http
           #:with-agent-loop
           #:ask))

(in-package #:cl-stack-sample/agent)

(defparameter +instructions+
  "You answer questions about lengths of time. For any sum of durations call
the add_durations tool; never add them yourself. Durations look like \"1h30m\",
\"45s\" or \"2d 4h\". Answer in one sentence."
  "System prompt of the duration agent.")

(defun %object (&rest kvs)
  "A JSON object (string-keyed hash table) from alternating keys and values."
  (let ((h (make-hash-table :test #'equal)))
    (loop for (k v) on kvs by #'cddr do (setf (gethash k h) v))
    h))

(defun %durations-argument (arguments)
  "The \"durations\" strings in the tool's JSON ARGUMENTS, or TOOL-INPUT-ERROR."
  (let* ((args (handler-case (json-protocol:decode arguments)
                 (json-protocol:json-parse-error (c)
                   (error 'tool-input-error :message (princ-to-string c)))))
         (items (and (hash-table-p args) (gethash "durations" args))))
    (unless (and (vectorp items) (plusp (length items)) (every #'stringp items))
      (error 'tool-input-error
             :message "\"durations\" must be a non-empty array of strings"))
    (coerce items 'list)))

(defun make-duration-tool ()
  "The add_durations tool. A bad duration reaches the model as a
TOOL-INPUT-ERROR, so it is told to fix the arguments and call again."
  (make-function-tool
   :name "add_durations"
   :description "Add durations such as \"1h30m\" and \"45m\"; returns the total, e.g. \"2h15m\"."
   :parameters (%object "type" "object"
                        "properties" (%object "durations"
                                              (%object "type" "array"
                                                       "items" (%object "type" "string")))
                        "required" (vector "durations"))
   :handler (lambda (arguments)
              (let ((texts (%durations-argument arguments)))
                (handler-case (apply #'cl-stack-sample:add-durations texts)
                  (cl-stack-sample:invalid-duration (c)
                    (error 'tool-input-error :message (princ-to-string c))))))))

(defun make-duration-agent (&key backend (max-steps 6))
  "An agent that answers duration questions with the add_durations tool.
BACKEND defaults to Anthropic (ANTHROPIC_API_KEY from the environment)."
  (make-ai-agent
   :name "durations"
   :backend (or backend
                (llm-protocol-anthropic:make-anthropic-backend
                 :default-model "claude-opus-5-5"))
   :instructions +instructions+
   :tools (list (make-duration-tool))
   :settings (make-agent-settings
              :max-steps max-steps
              :extra (list :retry-policy (make-retry-policy :max-attempts 4)))))

(defun use-async-http ()
  "Route HTTP through the cl-stack async backend on libuv."
  (setf http-backend-async:*event-backend-maker* #'event-backend-libuv:make-libuv-backend
        http-protocol:*http-backend* (http-backend-async:make-async-backend)))

(defmacro with-agent-loop (&body body)
  "Run BODY with a libuv event loop bound, as sync RUN-AI-AGENT expects."
  `(let* ((eb (event-backend-libuv:make-libuv-backend))
          (el (event-protocol:make-event-loop eb)))
     (event-protocol:with-event-backend (eb)
       (event-protocol:with-event-loop-var (el)
         ,@body))))

(defun ask (question &key backend)
  "Ask the duration agent QUESTION; → the answer text and the run."
  (unless backend (use-async-http))
  (let ((run (with-agent-loop
               (run-ai-agent (make-duration-agent :backend backend) question))))
    (values (agent-run-text run) run)))
