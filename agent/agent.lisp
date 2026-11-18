;;;; An ai-agent-protocol agent whose one tool is this project's library.
;;;; Pick the model provider with a "provider:model" designator: the :llm
;;;; argument, or $SAMPLE_LLM (default "anthropic"). See *PROVIDERS*.
;;;; Offline: pass any llm-protocol backend, e.g. the mock one (see the tests).

(defpackage #:cl-stack-sample/agent
  (:use #:cl #:ai-agent-protocol #:llm-protocol)
  (:export #:+instructions+
           #:*providers*
           #:*default-llm*
           #:make-llm-backend
           #:make-provider-backend
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

(defparameter *providers*
  '(("anthropic"     :anthropic nil                           nil                  "claude-opus-5-5")
    ("openai"        :openai    "https://api.openai.com/v1"   "OPENAI_API_KEY"     "gpt-4o-mini")
    ("openrouter"    :openai    "https://openrouter.ai/api/v1" "OPENROUTER_API_KEY" "openai/gpt-4o-mini")
    ("openai-compat" :openai    nil                           "OPENAI_API_KEY"     nil)
    ("lmstudio"      :openai    "http://127.0.0.1:1234/v1"    "LM_API_TOKEN"       nil)
    ("ollama"        :openai    "http://127.0.0.1:11434/v1"   nil                  nil)
    ("vllm"          :openai    "http://127.0.0.1:8000/v1"    nil                  nil)
    ("mock"          :mock      nil                           nil                  nil))
  "Providers MAKE-LLM-BACKEND knows: (name kind base-url api-key-env default-model).
KIND :ANTHROPIC uses llm-protocol-anthropic (ANTHROPIC_API_KEY, ANTHROPIC_BASE_URL);
:OPENAI uses llm-protocol-openai against BASE-URL (NIL: OPENAI_BASE_URL, else LM
Studio's address); :MOCK is the offline echo backend. Push an entry to add one.")

(defvar *default-llm* nil
  "Provider designator used when none is given. NIL: $SAMPLE_LLM at the time
the agent is made, else \"anthropic\".")

(defgeneric make-provider-backend (kind &key base-url api-key model)
  (:documentation "The llm-protocol backend for a *PROVIDERS* entry of KIND.
Add a method (and push a *PROVIDERS* entry) for a new kind of provider, as
the cl-stack-sample/vllm system does for :VLLM-CPP."))

(defmethod make-provider-backend ((kind (eql :anthropic)) &key base-url api-key model)
  (declare (ignore base-url api-key))
  (llm-protocol-anthropic:make-anthropic-backend :default-model model))

(defmethod make-provider-backend ((kind (eql :openai)) &key base-url api-key model)
  (llm-protocol-openai:make-openai-compat-backend
   :base-url base-url :api-key api-key :default-model model))

(defmethod make-provider-backend ((kind (eql :mock)) &key base-url api-key model)
  (declare (ignore base-url api-key model))
  (make-mock-llm-backend))

(defun make-llm-backend (designator)
  "An llm-protocol backend for DESIGNATOR, \"provider\" or \"provider:model\"
(\"openai:gpt-4o\", \"ollama:llama3.1:8b\" — the model is everything after the
first colon). An unknown provider signals LLM-UNKNOWN-PROVIDER with a
USE-VALUE restart that takes a backend to use instead."
  (check-type designator string)
  (let* ((colon (position #\: designator))
         (name (string-downcase (subseq designator 0 colon)))
         (model (and colon (< (1+ colon) (length designator))
                     (subseq designator (1+ colon))))
         (spec (assoc name *providers* :test #'string=)))
    (restart-case
        (progn
          (unless spec
            (error 'llm-unknown-provider
                   :name name
                   :message (format nil "known providers: ~{~a~^, ~}"
                                    (mapcar #'first *providers*))))
          (destructuring-bind (kind base-url key-env default-model) (rest spec)
            (make-provider-backend kind
                                   :base-url base-url
                                   :api-key (and key-env (uiop:getenv key-env))
                                   :model (or model default-model))))
      (use-value (backend)
        :report "Use another llm-protocol backend."
        backend))))

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

(defun make-duration-agent (&key backend
                                 (llm (or *default-llm* (uiop:getenv "SAMPLE_LLM") "anthropic"))
                                 (max-steps 6))
  "An agent that answers duration questions with the add_durations tool.
BACKEND is any llm-protocol backend; without it, LLM (a \"provider:model\"
designator, default *DEFAULT-LLM*) picks one through MAKE-LLM-BACKEND."
  (make-ai-agent
   :name "durations"
   :backend (or backend (make-llm-backend llm))
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

(defun ask (question &key backend llm)
  "Ask the duration agent QUESTION; → the answer text and the run.
BACKEND is an llm-protocol backend; otherwise LLM, a \"provider:model\"
designator (see MAKE-LLM-BACKEND), or $SAMPLE_LLM, or \"anthropic\"."
  (unless backend (use-async-http))
  (let* ((agent (apply #'make-duration-agent :backend backend
                       (and llm (list :llm llm))))
         (run (with-agent-loop (run-ai-agent agent question))))
    (values (agent-run-text run) run)))
