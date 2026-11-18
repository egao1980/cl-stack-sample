;;;; In-process vllm.cpp provider for the duration agent:
;;;;   (ask "…" :llm "vllm-cpp:/path/to/model.gguf")   or SAMPLE_LLM=vllm-cpp:…
;;;; The model is a GGUF path (or an HF directory); without one, VLLM_MODEL_PATH.
;;;; Needs the vllm-cpp native overlay (Metal on darwin/arm64, CUDA on linux/amd64).

(defpackage #:cl-stack-sample/vllm
  (:use #:cl)
  (:import-from #:cl-stack-sample/agent #:make-provider-backend #:*providers*)
  (:export #:*vllm-max-model-len*))

(in-package #:cl-stack-sample/vllm)

(defparameter *vllm-max-model-len* 2048
  "Context length the engine is loaded with. vllm.cpp's default KV pool (256
blocks) holds about 4064 tokens, so 4096 is refused at load; raise it only
with a larger pool (VLLM num-blocks / kv-cache-memory).")

(defmethod make-provider-backend ((kind (eql :vllm-cpp)) &key base-url api-key model)
  (declare (ignore base-url api-key))
  (let* ((path (or model (uiop:getenv "VLLM_MODEL_PATH")))
         (engine (vllm-cpp:load-engine :model-path path
                                       :max-model-len *vllm-max-model-len*)))
    (llm-backend-vllm-cpp:make-vllm-cpp-backend
     :model-path path
     :device (vllm-cpp:engine-device engine)
     :engine engine)))

(pushnew '("vllm-cpp" :vllm-cpp nil nil nil) *providers*
         :key #'first :test #'string=)
