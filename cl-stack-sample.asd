;;;; A sample Common Lisp project on cl-stack: a small library, its Rove
;;;; tests, and an AI agent that uses the library as a tool. Dependencies come
;;;; from OCI through cl-repo (`cl-repo sync`, `cl-repo test`).

(defsystem "cl-stack-sample"
  :version "0.1.0"
  :description "Durations like \"1h30m\": parse, format, add — with conditions and restarts"
  :author "egao1980"
  :license "MIT"
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "conditions")
               (:file "duration"))
  :in-order-to ((test-op (test-op "cl-stack-sample/tests"))))

(defsystem "cl-stack-sample/tests"
  :depends-on ("cl-stack-sample" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "duration-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))

(defsystem "cl-stack-sample/agent"
  :version "0.1.0"
  :description "An ai-agent-protocol agent with the duration library as its tool"
  :depends-on ("cl-stack-sample"
               (:version "ai-agent-protocol" "0.6.0")
               (:version "llm-protocol" "0.4.0")
               (:version "llm-protocol-anthropic" "0.2.0")
               (:version "llm-protocol-openai" "0.3.1")
               "json-protocol" "json-backend-jzon"
               "event-protocol" "event-backend-libuv"
               "http-backend-async")
  :pathname "agent"
  :serial t
  :components ((:file "agent"))
  :in-order-to ((test-op (test-op "cl-stack-sample/agent-tests"))))

(defsystem "cl-stack-sample/agent-tests"
  :depends-on ("cl-stack-sample/agent" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "agent-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
