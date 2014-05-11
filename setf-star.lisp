;;; -*- Mode: Lisp; Package: CLIM-INTERNALS -*-

;;;  (c) copyright 2001 by
;;;           Tim Moore (moore@bricoworks.com)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;;; Boston, MA  02111-1307  USA.

(in-package :clim-internals)

(defun setf-name-p (name)
  (and (listp name) (eq (car name) 'setf)))

;;; Many implementations complain if a defsetf definition and a setf function
;;; exist for the same place. Time to stop fighting that...

(defun make-setf*-gfn-name (function-name)
  (let* ((name-sym (cadr function-name)))
    `(setf ,(intern (format nil ".~A-~A."
                            (symbol-name name-sym)
                            (symbol-name '#:star))
                    (symbol-package name-sym)))))

(defmacro defgeneric* (fun-name lambda-list &body options)
  "Defines a SETF* generic function.  FUN-NAME is a SETF function
name.  The last argument is the single argument to the function in a
SETF place form; the other arguments are values collected from the
SETF new value form."
  (unless (setf-name-p fun-name)
    (error "~S is not a valid name for a SETF* generic function."
           fun-name))
  (flet ((gensym% (s) (gensym (symbol-name s))))
    (let* ((setf-name (cadr fun-name))
           (args (butlast lambda-list))
           (%values-store (mapcar #'gensym% args))
           (place (car (last lambda-list)))
           (%place (gensym% place))
           (gf (make-setf*-gfn-name fun-name)))
      (with-gensyms (dplace vplace nvplace setplace getplace env)
        `(progn
           (define-setf-expander ,setf-name (,%place &environment ,env)
             (values
              nil
              nil
              ;; CLHS (CLtL2) does not explicitly specify
              ;; that multiple values may stored by the third return
              ;; value from DEFINE-SETF-EXPANDER. However, CCL, ECL,
              ;; and SBCL are known to implement such multiple value
              ;; storage, with regards to DEFINE-SETF-EXPANDER.
              ;;
              ;; This revised DEFGENERIC* should be tested on other
              ;; Lisp implementations, and accompanied with a
              ;; corresponding regression test procedure.
              (quote (,@%values-store))
              `(funcall (function ,,gf) ,,@%values-store ,,%place)
              (quote (,setf-name ,%place))))
           (defgeneric ,gf ,lambda-list ,@options))))))


(defmacro defmethod* (name &body body)
  "Defines a SETF* method.  NAME is a SETF function name.  Otherwise,
like DEFMETHOD except there must exist a corresponding DEFGENERIC* form."
  (unless (setf-name-p name)
    (error "~S is not a valid name for a SETF* generic function." name))
  `(defmethod ,(make-setf*-gfn-name name) ,@body))
