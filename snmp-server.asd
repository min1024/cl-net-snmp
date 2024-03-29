;;;; -*- Mode: Lisp -*-
;;;; $Id: snmp-server.asd 878 2011-06-17 07:17:14Z binghe $

(unless (find-package ':snmp-system)
  (make-package ':snmp-system
                :use '(:common-lisp :asdf)))

(in-package :snmp-system)

(defsystem snmp-server
  :description "SNMP Server"
  :author "Chun Tian (binghe) <binghe.lisp@gmail.com>"
  :version "4.0"
  :licence "MIT"
  :depends-on (:snmp)
  :components ((:file "server-condition")
               (:file "snmp-server" :depends-on ("server-condition"))
               (:file "server-vacm" :depends-on ("snmp-server"))
               (:file "server-walk" :depends-on ("snmp-server"))
               (:file "server-base" :depends-on ("server-walk"))
               (:module "compiled-mibs"
                :components ((:file "lisp-mib")
                             #+abcl      (:file "abcl-mib")
                             #+allegro   (:file "franz-mib")
                             #+clozure   (:file "clozure-mib")
                             #+cmu       (:file "cmucl-mib")
                             #+ecl       (:file "ecl-mib")
                             #+lispworks (:file "lispworks-mib")
                             #+sbcl      (:file "sbcl-mib")
                             #+scl       (:file "scl-mib")))
               (:module "server"
                :depends-on ("server-base"
                             "compiled-mibs")
                :components ((:file "core")
                             (:file "lisp-base")
			     #+abcl      (:file "abcl")
                             #+allegro   (:file "allegro")
                             #+clozure   (:file "clozure")
                             #+cmu       (:file "cmucl")
                             #+ecl       (:file "ecl")
                             #+lispworks (:file "lispworks")
                             #+sbcl      (:file "sbcl")
                             #+cl-http   (:file "cl-http")))))

(defmethod perform :after ((op load-op) (c (eql (find-system :snmp-server))))
  (funcall (intern "LOAD-ALL-PATCHES" "SNMP") c))
