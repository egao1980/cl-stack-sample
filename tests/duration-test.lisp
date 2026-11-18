(defpackage #:cl-stack-sample/tests
  (:use #:cl #:rove #:cl-stack-sample))

(in-package #:cl-stack-sample/tests)

(deftest-parametrize parse-duration-reads-units
    ((text seconds)
     ("45s" 45)
     ("1h30m" 5400)
     ("2d 4h" 187200)
     ("1H" 3600)
     ("  90m  " 5400))
  (ok (= seconds (parse-duration text))))

(deftest-parametrize parse-duration-rejects
    ((text reason)
     ("" "empty duration")
     ("10" "missing unit")
     ("5x" "unknown unit")
     ("h" "expected a number"))
  (let ((c (handler-case (parse-duration text)
             (invalid-duration (c) c))))
    (ok (typep c 'invalid-duration))
    (ok (search reason (invalid-duration-reason c)))
    (ok (equal text (invalid-duration-text c)))))

(deftest format-duration-round-trips
  (ok (equal "0s" (format-duration 0)))
  (ok (equal "1h30m" (format-duration 5400)))
  (ok (equal "2d4h" (format-duration (parse-duration "2d 4h"))))
  (ok (equal "1h45m" (add-durations "1h" "45m"))))

(deftest use-value-restart-recovers
  (testing "a handler supplies the value"
    (ok (= 60 (handler-bind ((invalid-duration
                               (lambda (c) (use-value 60 c))))
                (parse-duration "one minute")))))
  (testing "parse-durations policies"
    (ok (equal '(60 3600) (parse-durations '("1m" "bad" "1h") :on-error :skip)))
    (ok (equal '(60 0 3600) (parse-durations '("1m" "bad" "1h") :on-error :zero)))
    (ok (signals (parse-durations '("1m" "bad")) 'invalid-duration))))
