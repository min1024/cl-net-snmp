;;;; -*- Mode: Lisp -*-
;;;; $Id: snmp-ui.asd 853 2011-03-18 20:15:00Z binghe $

(unless (find-package ':snmp-system)
  (make-package ':snmp-system
                :use '(:common-lisp :asdf)))

(in-package :snmp-system)

(defsystem snmp-ui
  :description "SNMP GUI Utility for LispWorks"
  :author "Chun Tian (binghe) <binghe.lisp@gmail.com>"
  :version "1.0"
  :licence "MIT"
  :depends-on (:snmp)
  :components ((:module "interface"
                :serial t
		:components ((:file "package")
                             (:file "fli-templates")
                             (:file "mibrowser")))))
