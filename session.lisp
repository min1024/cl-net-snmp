;;;; -*- Mode: Lisp -*-
;;;; $Id: session.lisp 843 2011-03-16 14:24:10Z binghe $

(in-package :snmp)

(defconstant +snmp-version-1+  0)
(defconstant +snmp-version-2c+ 1)
(defconstant +snmp-version-3+  3)

(defvar *default-snmp-version* +snmp-version-2c+)
(defvar *default-snmp-port* 161)
(defvar *default-snmp-community* "public")
(defvar *default-auth-protocol* :md5)
(defvar *default-priv-protocol* :des)

(defclass session ()
  ((socket            :type usocket:datagram-usocket
                      :accessor socket-of
                      :initarg :socket)
   (host              :type (or string integer)
                      :accessor host-of
                      :initarg :host)
   (port              :type integer
                      :accessor port-of
                      :initarg :port)
   (version           :type integer
                      :accessor version-of
                      :initarg :version))
  (:documentation "SNMP session base"))

(defclass v1-session (session)
  ((community         :type string
		      :accessor community-of
		      :initarg :community
		      :initform *default-snmp-community*)
   (version           :type integer
                      :accessor version-of
                      :initarg :version
		      :initform +snmp-version-1+))
  (:documentation "SNMP v1 session, community based"))

(defclass v2c-session (v1-session)
  ((version           :type integer
                      :accessor version-of
                      :initarg :version
		      :initform +snmp-version-2c+))
  (:documentation "SNMP v2c session, community based"))

(defclass v3-session (session)
  ((version           :type integer
                      :accessor version-of
                      :initarg :version
		      :initform +snmp-version-3+)
   (security-name     :type string
		      :reader security-name-of
		      :initarg :security-name)
   (security-level    :type (unsigned-byte 8)
		      :accessor security-level-of)
   (engine-id         :type string
		      :initarg :engine-id
                      :initform ""
		      :accessor engine-id-of)
   (engine-boots      :type integer
		      :initarg :engine-boots
                      :initform 0
		      :accessor engine-boots-of)
   (engine-time       :type integer
		      :initarg :engine-time
                      :initform 0
		      :accessor engine-time-of)
   (auth-protocol     :type (member :md5 :sha1 nil)
                      :initarg :auth-protocol
                      :initform nil
                      :accessor auth-protocol-of)
   (auth-key          :type octets
		      :initarg :auth-key
		      :accessor auth-key-of)
   (auth-local-key    :type octets
                      :initarg :auth-local-key
                      :accessor auth-local-key-of)
   (priv-protocol     :type (member :des :aes nil)
                      :initarg :priv-protocol
                      :initform nil
                      :accessor priv-protocol-of)
   (priv-key          :type octets
		      :initarg :priv-key
		      :accessor priv-key-of)
   (priv-local-key    :type octets
                      :initarg :priv-local-key
                      :accessor priv-local-key-of))
  (:documentation "SNMP v3 session, user security model"))

(defmethod initialize-instance :after ((session v3-session) &rest initargs)
  (declare (ignore initargs))
  (with-slots (version security-level auth-protocol priv-protocol) session
    (setf version +snmp-version-3+
          ;; msgFlags = Security-Level + Reportable:
          ;; .... .1.. = Reportable: Set
          ;; .... ..1. = Encrypted: Set
          ;; .... ...1 = Authenticated: Set
          security-level (logior (if auth-protocol #b01 #b00)
                                 (if priv-protocol #b10 #b00)))))

(defvar *snmp-class-map* (make-hash-table :test 'eq :size 3))

(eval-when (:load-toplevel :execute)
  (setf (gethash +snmp-version-1+ *snmp-class-map*) 'v1-session
        (gethash +snmp-version-2c+ *snmp-class-map*) 'v2c-session
        (gethash +snmp-version-3+ *snmp-class-map*) 'v3-session))

(defvar *snmp-version-map* (make-hash-table :test 'eq :size 9))

(eval-when (:load-toplevel :execute)
  (mapcar #'(lambda (x)
	      (setf (gethash (car x) *snmp-version-map*) (cdr x)))
	  `((:v1                . ,+snmp-version-1+)
	    (:v2c               . ,+snmp-version-2c+)
	    (:v3                . ,+snmp-version-3+)
	    (:version-1         . ,+snmp-version-1+)
	    (:version-2c        . ,+snmp-version-2c+)
	    (:version-3         . ,+snmp-version-3+)
            (,+snmp-version-1+  . ,+snmp-version-1+)
            (,+snmp-version-2c+ . ,+snmp-version-2c+)
            (,+snmp-version-3+  . ,+snmp-version-3+))))

(defun snmp-connect (host port)
  (usocket:socket-connect host port :protocol :datagram))

(defun open-session (host &key (port *default-snmp-port*)
                               version
                               (community *default-snmp-community*)
                               (create-socket t)
                               user auth priv)
  ;; first, what version we are talking about if version not been set?
  (let* ((real-version (or (gethash version *snmp-version-map*)
                           (if user +snmp-version-3+ *default-snmp-version*)))
         (args (list (gethash real-version *snmp-class-map*)
                     :host host :port port)))
    (when create-socket
      (nconc args (list :socket (snmp-connect host port))))
    (if (/= real-version +snmp-version-3+)
      ;; for SNMPv1 and v2c, only set the community
      (nconc args (list :community (or community *default-snmp-community*)))
      ;; for SNMPv3, we detect the auth and priv parameters
      (progn
        (nconc args (list :security-name user))
        (when auth
          (if (atom auth)
            (nconc args (list :auth-protocol *default-auth-protocol*)
                   (if (stringp auth)
                     (list :auth-key (generate-ku auth :hash-type *default-auth-protocol*))
                     (list :auth-local-key (coerce auth 'octets))))
            (destructuring-bind (auth-protocol . auth-key) auth
              (nconc args (list :auth-protocol auth-protocol)
                     (let ((key (if (atom auth-key) auth-key (car auth-key))))
                       (if (stringp key)
                         (list :auth-key (generate-ku key :hash-type auth-protocol))
                         (list :auth-local-key (coerce key 'octets))))))))
        (when priv
          (if (atom priv)
            (nconc args (list :priv-protocol *default-priv-protocol*)
                   (if (stringp auth)
                     (list :priv-key (generate-ku priv :hash-type :md5))
                     (list :priv-local-key (coerce priv 'octets))))
            (destructuring-bind (priv-protocol . priv-key) priv
              (nconc args (list :priv-protocol priv-protocol)
                     (let ((key (if (atom priv-key) priv-key (car priv-key))))
                       (if (stringp key)
                         (list :priv-key (generate-ku key :hash-type :md5))
                         (list :priv-local-key (coerce key 'octets))))))))))
    (apply #'make-instance args)))

(defun close-session (session)
  (declare (type session session))
  (when (slot-boundp session 'socket)
    (usocket:socket-close (socket-of session))))

(defmacro with-open-session ((session &rest args) &body body)
  `(let ((,session (open-session ,@args)))
     (unwind-protect
         (progn ,@body)
       (close-session ,session))))
