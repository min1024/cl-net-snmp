;;;; -*- Mode: Lisp -*-
;;;; $Id: abcl.lisp 862 2011-03-20 06:52:18Z binghe $

(in-package :snmp)

(def-scalar-variable "sysObjectID" (agent)
  (oid "clNetSnmpAgentABCL"))
