(in-package #:cl-stack-sample)

(define-condition duration-error (error) ()
  (:documentation "Root of the errors this library signals."))

(define-condition invalid-duration (duration-error)
  ((text :initarg :text :reader invalid-duration-text)
   (position :initarg :position :reader invalid-duration-position)
   (reason :initarg :reason :reader invalid-duration-reason))
  (:documentation "TEXT is not a duration; POSITION is where reading stopped.")
  (:report (lambda (c s)
             (format s "~s is not a duration (at ~d: ~a)"
                     (invalid-duration-text c)
                     (invalid-duration-position c)
                     (invalid-duration-reason c)))))
