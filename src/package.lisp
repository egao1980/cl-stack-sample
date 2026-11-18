(defpackage #:cl-stack-sample
  (:use #:cl)
  (:nicknames #:sample)
  (:documentation "Durations written as \"1h30m\", \"45s\" or \"2d 4h\".")
  (:export #:duration-error
           #:invalid-duration
           #:invalid-duration-text
           #:invalid-duration-position
           #:invalid-duration-reason
           #:parse-duration
           #:format-duration
           #:add-durations
           #:parse-durations))
