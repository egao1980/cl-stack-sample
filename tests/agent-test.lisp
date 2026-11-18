(defpackage #:cl-stack-sample/agent-tests
  (:use #:cl #:rove #:cl-stack-sample/agent)
  (:import-from #:llm-protocol
                #:make-mock-llm-backend #:make-llm-response
                #:make-llm-text-part #:make-llm-tool-call-part
                #:llm-turn-parts #:llm-tool-result-part-content)
  (:import-from #:ai-agent-protocol
                #:agent-run-invocations #:agent-invocation-result
                #:agent-invocation-error-p))

(in-package #:cl-stack-sample/agent-tests)

(defun scripted (&rest calls)
  "A mock model: each of CALLS (a JSON arguments string) is one add_durations
call; then it answers with the last tool result."
  (let ((pending calls))
    (make-mock-llm-backend
     :handler (lambda (b turns &key &allow-other-keys)
                (declare (ignore b))
                (if pending
                    (make-llm-response
                     :parts (list (make-llm-tool-call-part
                                   :id (format nil "c~d" (length pending))
                                   :name "add_durations"
                                   :arguments (pop pending)))
                     :finish-reason :tool-use)
                    (make-llm-response
                     :parts (list (make-llm-text-part
                                   :text (format nil "Total: ~a"
                                                 (llm-tool-result-part-content
                                                  (first (llm-turn-parts (car (last turns))))))))
                     :finish-reason :stop))))))

(deftest agent-adds-with-the-library
  (multiple-value-bind (text run)
      (ask "1h30m plus 45m?" :backend (scripted "{\"durations\":[\"1h30m\",\"45m\"]}"))
    (ok (equal "Total: 2h15m" text))
    (ok (equal "2h15m" (agent-invocation-result (first (agent-run-invocations run)))))))

(deftest bad-duration-is-a-fixable-tool-error
  (multiple-value-bind (text run)
      (ask "1 hour plus 5m?"
           :backend (scripted "{\"durations\":[\"1 hour\",\"5m\"]}"
                              "{\"durations\":[\"1h\",\"5m\"]}"))
    (let ((first-call (first (agent-run-invocations run))))
      (ok (agent-invocation-error-p first-call))
      (ok (search "is not a duration" (agent-invocation-result first-call)))
      (ok (search "Fix the arguments" (agent-invocation-result first-call))))
    (ok (equal "Total: 1h5m" text))))
