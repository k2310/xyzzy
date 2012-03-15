;; -*- mode:lisp; package:makelc -*-
;;
;;; Usage:
;;
;; - M-x makelc
;;   compiler �p�b�P�[�W�� lisp �p�b�P�[�W�̊֐����R���p�C����A
;;   $XYZZY/lisp �t�H���_�ȉ��̍X�V���ꂽ*.l ���ăR���p�C�����ă����[�h
;;
;; - C-u M-x makelc
;;   compiler �p�b�P�[�W�� lisp �p�b�P�[�W�̊֐����R���p�C����A
;;   $XYZZY/lisp �t�H���_�ȉ���*.l ���ăR���p�C�����ă����[�h
;;
;; - (makelc:compile-files &key dir force-recompile)
;;   �w��f�B���N�g���ȉ��̍X�V���ꂽ*.l ���ăR���p�C��
;;   force-recompile �� non-nil �̏ꍇ�͏�ɍăR���p�C��
;;
;; - (makelc:compile-package :packagename)
;;   �w��p�b�P�[�W���Œ�`����Ă��関�R���p�C���̊֐����R���p�C��
;;
;; - (makelc:reload-files)
;;   lisp/�z���̃��W���[�������ׂčēǂݍ���
;;
;;; Code:

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "compile"))

(defpackage :makelc
  (:use :lisp :ed))

(in-package :makelc)
(export '(compile-package
	  compile-files
          reload-files
          ))

(defmacro time (form)
  `(let ((start (get-internal-real-time))
	 (result (multiple-value-list ,form)))
     (format t "~&~V@{-~}~%~D msec~%~%" 30 (- (get-internal-real-time) start))
     (values-list result)))

(defun not-compiled-functions (pkg)
  (let ((fns nil)
	(p (find-package pkg)))
    (do-symbols (s p)
      (when (and (fboundp s)
		 (not (macro-function s))
		 (eq p (symbol-package s)))
	(let ((f (symbol-function s)))
	  (when (not (or (si:*builtin-function-p f)
			 (compiled-function-p f)
			 (not (functionp f))
			 (and (si:*closurep f)
			      (si:closure-variable f))))
	    (push s fns)))))
    (nreverse fns)))

(defun compile-package (pkg)
  (format t "compiling <~A> ...~%" pkg)
  (time
   (dolist (f (not-compiled-functions pkg))
     (format t "~A ..." f)
     (goto-char (point-max))
     (refresh-screen)
     (handler-case
	 (progn
	   (compile f)
	   (princ "ok"))
       (error (c)
	 (format t "error~%*****~%~A~%*****"
		 (si:*condition-string c))))
     (terpri))))

(defun compile-files (&key (dir (merge-pathnames "lisp" (si:system-root)))
                           force-recompile)
  (let ((files (directory dir :absolute t :wild "*.l" :recursive t)))
    (format t "compiling ~D files ...~%" (length files))
    (time
     (dolist (src files)
       (let ((bin (compile-file-pathname src)))
         (when (or force-recompile
                   (file-newer-than-file-p src bin))
           (compile-file src)))))))

(defun reload-files ()
  (labels ((lisp-module-p (module)
             (file-exist-p (merge-pathnames (format nil "lisp/~A.l" module)
                                            (si:system-root)))))
    (let ((lisp-modules (remove-if-not #'lisp-module-p *modules*)))
      (setf *modules* (remove-if #'lisp-module-p *modules*))
      (format t "reloading ~D modules ...~%" (length lisp-modules))
      (time
       (dolist (module lisp-modules)
         (load-library module))))))

(defun user::makelc ()
  (interactive)
  (let ((buf (create-new-buffer "*compile log*")))
    (set-buffer buf)
    (setup-temp-buffer buf)
    (with-output-to-buffer (buf)
      (compile-package :compiler)
      (compile-package :lisp)
      (compile-files :force-recompile *prefix-args*)
      (reload-files)
      (let ((dump (si:dump-image-path)))
        (when (file-exist-p dump)
          (delete-file dump)))
      (goto-char (point-max))
      (refresh-screen)
      )))

(provide "makelc")