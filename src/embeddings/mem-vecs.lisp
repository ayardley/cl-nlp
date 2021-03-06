;;; (c) 2016-2017 Vsevolod Dyomkin

(in-package #:nlp.embeddings)
(named-readtables:in-readtable rutilsx-readtable)


(defclass mem-vecs (vecs)
  ((dict :initarg :dict :accessor vecs-dict)
   (default :initarg :default :accessor vecs-default))
  (:documentation
   "Word vectors stored in memory."))

(defmethod slot-unbound (class (obj mem-vecs) (slot-name (eql 'default)))
  (:= @instance.default (make-array @obj.order :element-type 'single-float)))

(defclass lazy-mem-vecs (mem-vecs)
  ((understream :initarg :understream :accessor vecs-understream))
  (:documentation
   "Word vectors stored in memory, but loaded only on-demand."))


(defmethod 2vec ((vecs mem-vecs) word)
  (get# (normalize vecs word) @vecs.dict))
  
(defmethod 2vec ((vecs lazy-mem-vecs) word)
  (with ((norm (normalize vecs word))
         (rez (get# norm @vecs.dict)))
    (cond ((numberp rez)
           (file-position @vecs.understream rez)
           (read-word @vecs.understream)
           (set# norm @vecs.dict (read-vec @vecs.order @vecs.understream)))
          ((null rez)
           @vecs.default)
          (t rez))))

(defgeneric init-vecs (vecs file)
  (:documentation
   "Initialize word VECS from FILE.")
  (:method ((vecs mem-vecs) file)
    (let ((dict #h(equal))
          (cc 0))
      (with-open-file (in file)
        (loop :for word := (read-word in t) :while word :do
          (when (zerop (rem (:+ cc) 10000)) (princ "."))
          (:= (? dict (normalize vecs word))
              (read-vec @vecs.order in))))
      (:= @vecs.dict dict)
      vecs))
  (:method ((vecs lazy-mem-vecs) file)
    (let ((dict #h(equal))
          (off 0)
          (cc 0)
          (in (open file :external-format :utf8)))
      (:= @vecs.understream in)
      (loop :for line := (read-line in nil)
            :while (and line (not (blankp line))) :do
        (when (zerop (rem (:+ cc) 10000)) (princ "."))
        (let ((word (slice line 0 (position-if ^(member % '(#\Space #\Tab))
                                               line))))
          (:= (? dict (normalize vecs word)) off)
          (:= off (file-position in))))
      (:= @vecs.dict dict)
      vecs)))

(defun read-word (stream &optional return)
  "Read a word from STREAM until whitespace and optionally RETURN it."
  (loop :for char := (read-char stream nil)
        :until (or (null char)
                   (member char '(#\Space #\Tab)))
        :collect char :into word
        :finally (when return
                   (return (coerce (reverse word) 'string)))))

(defun read-vec (order stream)
  "Read word vectors of ORDER from stream"
  (let ((rez (make-array order :element-type 'single-float)))
    (dotimes (i order)
      (:= (aref rez i) (coerce (read stream) 'single-float)))
    rez))
