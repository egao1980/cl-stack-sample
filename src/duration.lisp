(in-package #:cl-stack-sample)

(defparameter *units*
  '((#\d . 86400) (#\h . 3600) (#\m . 60) (#\s . 1))
  "Unit letters and their length in seconds, largest first.")

(declaim (ftype (function (string) (values (integer 0) &optional)) %parse-duration))
(defun %parse-duration (text)
  "Seconds in TEXT, or signal INVALID-DURATION."
  (let ((total 0)
        (pos 0)
        (seen nil)
        (end (length text)))
    (flet ((fail (reason)
             (error 'invalid-duration :text text :position pos :reason reason)))
      (loop
        (loop while (and (< pos end) (char= #\Space (char text pos))) do (incf pos))
        (when (>= pos end) (return))
        (multiple-value-bind (n next) (parse-integer text :start pos :junk-allowed t)
          (unless n (fail "expected a number"))
          (when (minusp n) (fail "negative amount"))
          (setf pos next)
          (when (>= pos end) (fail "missing unit (d, h, m or s)"))
          (let ((unit (assoc (char-downcase (char text pos)) *units*)))
            (unless unit (fail (format nil "unknown unit ~s" (char text pos))))
            (incf total (* n (cdr unit)))
            (incf pos)
            (setf seen t))))
      (unless seen (fail "empty duration"))
      total)))

(defun parse-duration (text)
  "Seconds in TEXT such as \"1h30m\", \"45s\" or \"2d 4h\".
Signals INVALID-DURATION with a USE-VALUE restart: invoke it with the
number of seconds to return instead."
  (check-type text string)
  (restart-case (%parse-duration text)
    (use-value (seconds)
      :report "Use another number of seconds."
      :interactive (lambda () (list (eval (read *query-io*))))
      seconds)))

(defun format-duration (seconds)
  "\"1h30m\" for 5400. Zero is \"0s\"."
  (check-type seconds (integer 0))
  (if (zerop seconds)
      "0s"
      (with-output-to-string (s)
        (loop for (unit . size) in *units*
              do (multiple-value-bind (n rest) (floor seconds size)
                   (when (plusp n) (format s "~d~c" n unit))
                   (setf seconds rest))))))

(defun add-durations (&rest texts)
  "The sum of TEXTS, formatted: (add-durations \"1h\" \"45m\") → \"1h45m\"."
  (format-duration (reduce #'+ texts :key #'parse-duration)))

(defun parse-durations (texts &key (on-error :signal))
  "Seconds for each of TEXTS. ON-ERROR decides what an invalid one becomes:
:SIGNAL (the default) lets INVALID-DURATION through, :SKIP drops it, and
:ZERO counts it as 0. The policy is a HANDLER-BIND that invokes the
USE-VALUE restart PARSE-DURATION establishes, not a HANDLER-CASE."
  (check-type on-error (member :signal :skip :zero))
  (let ((values
          (handler-bind ((invalid-duration
                           (lambda (c)
                             (case on-error
                               (:skip (use-value :skip c))
                               (:zero (use-value 0 c))))))
            (mapcar #'parse-duration texts))))
    (remove :skip values)))
