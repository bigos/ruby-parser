(in-package :ruby-parser.ast)

(deftype proper-list (&optional element)
  (declare (ignore element))
  'list)

(defmacro defvariant (name-and-options &body clauses)
  (setq name-and-options (ensure-list name-and-options))
  (let ((variant-name (first name-and-options))
        (variant-constructor-lambda-list (third (assoc :constructor (cdr name-and-options)))))
    `(progn
       (defstruct ,name-and-options)
       ,@(iter (for (name-and-options . slot-specs) in clauses)
               (for (name . options) = (ensure-list name-and-options))
               (for (constructor-name constructor-lambda-list)
                    = (aif (assoc :constructor options)
                           (list (second it) (third it))
                           (list (symbolicate :make- name)
                                 (append (mapcar #'ensure-car slot-specs)
                                         variant-constructor-lambda-list))))
               (collect
                `(defstruct (,name ,@(remove :constructor options :key #'car)
                                   (:include ,variant-name)
                                   (:constructor ,constructor-name ,constructor-lambda-list))
                   ,@(iter (for slot-spec in slot-specs)
                           (for (slot-name slot-type) = (ensure-list slot-spec))
                           (collect`(,slot-name (required-argument) :type ,(or slot-type t))))))))))

(defstruct node loc)

(defmacro defnode (name &body clauses)
  `(defvariant (,name (:include node)
                      (:constructor ,(symbolicate :make- name) (&key loc)))
     ,@clauses))

;;; Literals

(defnode literal
  (string-lit (value (proper-list string-content)))
  (xstring-lit (value (proper-list string-content)))
  (symbol-lit (value (proper-list string-content)))
  (integer-lit (value integer))
  (float-lit (value float))
  ((regexp-lit (:constructor make-regexp-lit (value &key option loc)))
   (value (proper-list string-content))
   (option regexp-option)))

(deftype string-content ()
  '(or string expr))

(deftype regexp-option ()
  '(member nil :once))

;;; Variables

(defnode variable
  (lvar (name string))
  (dvar (name string))
  (ivar (name string))
  (cvar (name string))
  (gvar (name string))
  (const (path cpath))
  (pvar (name pseudo-variable)))

(defnode cpath
  (cpath-base (name string))
  (cpath-rel (expr expr)
             (name string))
  (cpath-abs (path cpath)))

(deftype pseudo-variable ()
  '(member :nil :true :false :self :__FILE__ :__LINE__))

;;; Parameters

(defnode parameter
  (req-param (name string))
  (opt-param (name string)
             (init expr))
  (rest-param (name string))
  (star-param)
  (block-param (name string)))

;;; Arguments

(defnode argument
  (value-arg (expr expr))
  (splat-arg (expr expr))
  (block-arg (expr expr))
  (hash-arg (list (proper-list expr))))

;;; LHS

(defnode lhs
  (lhs-var (var variable))
  (lhs-decl (var variable))
  (lhs-dest (list (proper-list lhs)))
  (lhs-rest (lhs lhs))
  (lhs-star)
  (lhs-attr (self expr)
            (name string))
  (lhs-aref (self expr)
            (args (proper-list argument)))
  (lhs-op (lhs lhs)
          (name string))
  (lhs-or (lhs lhs))
  (lhs-and (lhs lhs)))

;;; Misc

(defstruct (block (:include node)
                  (:constructor make-block (lhs body &key loc)))
  (lhs (required-argument) :type (proper-list lhs))
  (body (required-argument) :type (proper-list stmt)))

(deftype assign-kind ()
  '(member :single :svalue :multi))

;;; Statements

(defnode stmt
  (alias-stmt (new string)
              (old string))
  (undef-stmt (list (proper-list string)))
  (if-mod-stmt (body stmt)
               (test expr))
  (unless-mod-stmt (body stmt)
                   (test expr))
  (while-mod-stmt (body stmt)
                  (test expr))
  (until-mod-stmt (body stmt)
                  (test expr))
  (rescue-mod-stmt (body stmt)
                   (else stmt))
  (pre-exec-stmt (body (proper-list stmt)))
  (post-exec-stmt (body (proper-list stmt)))
  (expr-stmt (expr expr)))

;;; Expressions

(defnode expr
  (lit-expr (lit literal))
  (var-expr (var variable))
  (nth-ref-expr (index fixnum))
  (back-ref-expr (char character))
  (array-expr (args (proper-list argument)))
  (hash-expr (args (proper-list expr)))
  (dot2-expr (lhs expr)
             (rhs expr))
  (dot3-expr (lhs expr)
             (rhs expr))
  (not-expr (test expr))
  (and-expr (lhs expr)
            (rhs expr))
  (or-expr (lhs expr)
           (rhs expr))
  (defined-expr (test expr))
  (tern-expr (test expr)
             (then expr)
             (else expr))
  (if-expr (test expr)
           (then (proper-list stmt))
           (else (proper-list stmt)))
  (unless-expr (test expr)
               (then (proper-list stmt))
               (else (proper-list stmt)))
  (while-expr (test expr)
              (body (proper-list stmt)))
  (until-expr (test expr)
              (body (proper-list stmt)))
  (for-expr (lhs lhs)
            (gen expr)
            (body (proper-list stmt)))
  ((case-expr (:constructor make-case-expr (&key (test nil) (whens nil) (else nil) loc)))
   (test (or null expr))
   (whens (proper-list (cons (proper-list argument)
                             (proper-list stmt))))
   (else (proper-list stmt)))
  ((break-expr (:constructor make-break-expr (&key (args nil) loc)))
   (args (proper-list argument)))
  ((next-expr (:constructor make-next-expr (&key (args nil) loc)))
   (args (proper-list argument)))
  (redo-expr)
  (retry-expr)
  ((call-expr (:constructor make-call-expr (&key (self nil) name (args nil) (block nil) loc)))
   (self (or null expr))
   (name string)
   (args (proper-list argument))
   (block (or null block)))
  ((return-expr (:constructor make-return-expr (&key (args nil) loc)))
   (args (proper-list argument)))
  ((yield-expr (:constructor make-yield-expr (&key (args nil) loc)))
   (args (proper-list argument)))
  ((super-expr (:constructor make-super-expr (&key (args nil) (block nil) loc)))
   (args (or (proper-list argument) (member t)))
   (block (or null block)))
  (assign-expr (lhs lhs)
               (rhs expr)
               (kind assign-kind))
  ((body-stmt (:constructor make-body-stmt (&key (body nil) (rescues nil) (else nil) (ensure nil))))
   (body (proper-list stmt))
   (rescues (proper-list (cons (proper-list argument)
                               (proper-list stmt))))
   (else (proper-list stmt))
   (ensure (proper-list stmt)))
  ((class-expr (:constructor make-class-expr (path body &key (super nil) loc)))
   (path cpath)
   (super (or null expr))
   (body body-stmt))
  (sclass-expr (expr expr)
               (body body-stmt))
  (module-expr (path cpath)
               (body body-stmt))
  (defn-expr (name string)
             (params (proper-list parameter))
             (body body-stmt))
  (defs-expr (expr expr)
             (name string)
             (params (proper-list parameter))
             (body body-stmt))
  (begin-expr (body body-stmt))
  (block-expr (body (proper-list stmt))))

;;; Export

(labels ((subclasses (class)
           (let ((direct-subclasses (closer-mop:class-direct-subclasses class)))
             (remove-duplicates (apply #'append direct-subclasses (mapcar #'subclasses direct-subclasses))))))
  (iter (with node = (find-class 'node))
        (for class in (cons node (subclasses node)))
        (for class-name = (class-name class))
        (for constructor = (symbolicate :make- class-name))
        (for predicate = (symbolicate class-name :-p))
        (export class-name)
        (export constructor)
        (export predicate)
        (iter (for slot in (closer-mop:class-direct-slots class))
              (for slot-name = (closer-mop:slot-definition-name slot))
              (for accessor = (symbolicate class-name :- slot-name))
              (export slot-name)
              (export accessor))))
