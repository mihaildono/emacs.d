;;; chunyang-elisp.el --- Utilities for Emacs Lisp  -*- lexical-binding: t; -*-

;; Copyright (C) 2015, 2017  Chunyang Xu

;; Author: Chunyang Xu <mail@xuchunyang.me>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Utilities for Emacs Lisp

;;; Code:


;; TODO: Log


;;; package
(defun open-package-melpa-page (package)
  "Adopt from `describe-package'."
  (interactive
   (let* ((guess (or (function-called-at-point)
                     (symbol-at-point))))
     (require 'finder-inf nil t)
     ;; Load the package list if necessary (but don't activate them).
     (unless package--initialized
       (package-initialize t))
     (let ((packages (append (mapcar 'car package-alist)
                             (mapcar 'car package-archive-contents)
                             (mapcar 'car package--builtins))))
       (unless (memq guess packages)
         (setq guess nil))
       (setq packages (mapcar 'symbol-name packages))
       (let ((val
              (completing-read (if guess
                                   (format "Describe package (default %s): "
                                           guess)
                                 "Describe package: ")
                               packages nil t nil nil (when guess
                                                        (symbol-name guess)))))
         (list (intern val))))))

  (if (not (or (package-desc-p package) (and package (symbolp package))))
      (message "No package specified")
    (browse-url (format "http://melpa.org/#/%s"
                        (symbol-name package)))))

(defun describe-package--add-melpa-link (pkg)
  (let* ((desc (if (package-desc-p pkg)
                   pkg
                 (cadr (assq pkg package-archive-contents))))
         (name (if desc (package-desc-name desc) pkg))
         (archive (if desc (package-desc-archive desc)))
         (melpa-link (format "https://melpa.org/#/%s" name)))
    (when (equal archive "melpa")
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward "Summary:" nil t)
          (forward-line 1)
          (package--print-help-section "MELPA")
          (help-insert-xref-button melpa-link 'help-url melpa-link)
          (insert "\n"))))))

(when (>= emacs-major-version 25)
  (advice-add 'describe-package-1 :after #'describe-package--add-melpa-link))


;;; Upgrade packages without 'M-x package-list-packages'
(defun package--outdated-packages ()
  "Return a list of names of packages outdated."
  (cl-loop for p in (mapcar #'car package-alist)
           with get-version = (lambda (pkg where)
                                (let ((desc (cadr (assq pkg where))))
                                  (and desc (package-desc-version desc))))
           for v1 = (funcall get-version p package-alist)
           for v2 = (funcall get-version p package-archive-contents)
           when (and v1 v2 (version-list-< v1 v2))
           collect p))

;; TODO: Finish this (NOTE: package-utils provides this kind of function)
(defun package-upgrade ()
  (interactive)
  (mapc (lambda (p)
          (let ((mode-line-process '(t (format "Upgrading %s..." p))))
            (force-mode-line-update)
            (package-install (cadr (assq p package-archive-contents)))
            (package-delete (cadr (assq p package-alist)))))
        (package--outdated-packages)))

;; (when (>= emacs-major-version 25)
;;   (define-advice package-install (:around (orig-fun &rest args) update-pkg-database-if-needed)
;;     (if (called-interactively-p 'any)
;;         (condition-case err
;;             (apply orig-fun args)
;;           (file-error
;;            (message "%s" (error-message-string err))
;;            (sit-for 1)
;;            (message "Refreshing package database...")
;;            (package-refresh-contents)
;;            (apply orig-fun args)))
;;       (apply orig-fun args))))

;; This ugly hack is to reuse the interactive from of `package-install'.
;; (eval
;;  `(defun package-install-maybe-refresh (pkg &optional dont-select)
;;     "Like `package-install' but call `package-refresh-contents' once if PKG is not found."
;;     ,(interactive-form 'package-install)
;;     (condition-case err
;;         (package-install pkg dont-select)
;;       (file-error
;;        (message "%s" (error-message-string err))
;;        (sit-for .5)
;;        (package-refresh-contents)
;;        (package-install pkg dont-select)))))


;;; Another C-j for `lisp-interaction-mode'

;;*    Sample                                                           */
;;*---------------------------------------------------------------------*/
;; (setq x 23)
;;     ⇒ 23

;; (cl-incf x)
;;     ⇒ 24

;; (defun hi ()
;;   (message "hi"))
;;     ⇒ hi
;;*---------------------------------------------------------------------*/

;; (unless (version< emacs-version "25")
;;   (bind-key "C-j" #'my-eval-print-last-sexp lisp-interaction-mode-map))

(defun chunyang-disable-some-modes-in-scratch ()
  (dolist (mode '(aggressive-indent-mode ipretty-mode))
    (when (and (fboundp mode) mode)
      (funcall mode -1))))

(add-hook 'lisp-interaction-mode-hook #'chunyang-disable-some-modes-in-scratch)

(defun chunyang-eval-print-last-sexp (&optional eval-last-sexp-arg-internal)
  "Adapted from `eval-print-last-sexp'."
  (interactive "P")
  (let ((standard-output (current-buffer))
        (error-descriptor nil))
    (terpri)
    (let* ((p0 (point))
           (p1 (condition-case err
                   (progn (eval-last-sexp (or eval-last-sexp-arg-internal t))
                          (point))
                 (error (setq error-descriptor err))))
           (prompt (if error-descriptor
                       "error-> "       ; error→
                     "     => "         ; ⇒
                     )))
      (if (not error-descriptor)
          (progn (goto-char p0)
                 (princ prompt)
                 (goto-char (+ p1 (length prompt))))
        (princ prompt)
        (princ (error-message-string error-descriptor))))
    (terpri)
    (when error-descriptor
      ;; Re-throw the error signal
      (signal (car error-descriptor) (cdr error-descriptor)))))

(defun chunyang-eval-print-last-sexp-use-comment ()
  (interactive)
  (let ((standard-output (current-buffer)))
    (let ((res (eval (eval-sexp-add-defvars (elisp--preceding-sexp))
                     lexical-binding)))
      (princ ";=> ")
      (princ res)
      ;; Indent comment
      (comment-dwim nil))))

(defun chunyang-current-line-empty-p ()
  (string= "" (buffer-substring (line-beginning-position)
                                (line-end-position))))

(defun chunyang-macroexpand-print-last-sexp ()
  (interactive)
  (let ((standard-output (current-buffer)))
    (terpri)
    (let ((res (macroexpand (elisp--preceding-sexp))))
      (princ "     ≡ ")
      (princ res)
      (unless (chunyang-current-line-empty-p) (terpri)))))


(define-minor-mode display-pos-mode
  "Display position in mode line mainly for testing and debugging."
  :global t
  :lighter (:eval (format " [%d]" (point))))


;; Display function's short docstring along side with args in eldoc
(when (>= emacs-major-version 25)
  (define-advice elisp-get-fnsym-args-string (:around (orig-fun &rest r) append-func-doc)
    (concat
     (apply orig-fun r)
     (let* ((f (car r))
            (fdoc
             (and (fboundp f)
                  (documentation f 'raw)))
            (fdoc-one-line
             (and fdoc
                  (substring fdoc 0 (string-match "\n" fdoc)))))
       (when (and fdoc-one-line
                  (not (string= "" fdoc-one-line)))
         (concat "  |  " (propertize fdoc-one-line 'face 'italic)))))))


;; Misc
(defun describe-command (command)
  (interactive
   (let* ((fn (function-called-at-point))
          (cmd (and (commandp fn) fn))
          val)
     (setq val (completing-read (if cmd
                                    (format "Describe command (default %s): " cmd)
                                  "Describe command: ")
                                obarray 'commandp t nil nil
                                (and cmd (symbol-name cmd))))
     (list (if (equal val "")
               cmd (intern val)))))
  (describe-function command))


;; Byte-code, disassemble

(define-advice disassemble (:after (object &rest _) revert-buffer)
  "Make `g' (`revert-buffer') works for *Disassemble* buffer."
  (with-current-buffer "*Disassemble*"
    (unless (eq revert-buffer-function 'disassemble--revert-buffer)
      (setq-local revert-buffer-function
                  (defun disassemble--revert-buffer (_ignore-auto _noconfirm)
                    (disassemble object))))))


;;; Eval

(defun chunyang-eval-region-as-key (beg end)
  "Eval region as Emacs key."
  ;; The region can be Emacs key:
  ;;
  ;; [?\C-u ?\C-n]
  ;; "\C-u \C-n"
  ;; C-u M-x emacs-version RET
  (interactive "r")
  (let* ((sel (buffer-substring-no-properties beg end))
         (key (if (member (aref sel 0) '(?\" ?\[) )
                  (read sel)
                (kbd sel))))
    (deactivate-mark)
    (command-execute key)))

(defun chunyang-eval-on-region (beg end)
  "Eval a sexp on the region, local var `beg', `end' and `text' can be used.'"
  (interactive "r")
  (let ((text (buffer-substring-no-properties beg end)))
    (eval (read--expression "Eval on region (local: beg, end, text): ")
          ;; hmm, really necessary? I still don't know very well on
          ;; Emacs Lisp scope/environment
          (list (cons 'beg beg)
                (cons 'end end)
                (cons 'text text)))))


;;; Key

(defun chunyang-insert-command-name-by-key ()
  (interactive)
  (insert (format "%s" (key-binding (read-key-sequence "Key: ")))))

(defun chunyang-insert-key-by-key (&optional ask-for-kind)
  (interactive "P")
  (let ((kind (if ask-for-kind
                  (let ((choices '(("Human-readable String" . human)
                                   ("Emacs Lisp String"     . string)
                                   ("Emacs Lisp Vector"     . vector))))
                    (cdr (assoc (completing-read "Insert key as: " choices nil t)
                                choices)))
                'human))
        (key (read-key-sequence "Key: ")))
    (cl-case kind
      (human  (insert (key-description key)))
      (string (insert key))
      (vector (insert (format "%s" (read-kbd-macro key t)))))))

(defvar chunyang-format-command-on-key--formats
  '(("Markdown     `C-n` (`next-line`)"          . markdown)
    ("Markdown kbd <kbd>C-n</kbd> (`next-line`)" . markdown-kbd)
    ("Org          ~C-n~ (~next-line~)"          . org)
    ("Emacs Lisp   C-n (`next-line')"            . emacs-lisp)
    ("Default      'C-n' ('next-line')"          . default)))

(defun chunyang-format-command-on-key--default-format ()
  (cl-case major-mode
    (emacs-lisp-mode          'emacs-lisp)
    (org-mode                 'org)
    ((markdown-mode gfm-mode) 'markdown)
    (t                        'default)))

(defun chunyang-format-command-on-key (buffer key &optional format)
  "Format command on KEY in BUFFER in FORMAT.
With prefix arg, ask the format to use, otherwise, the format is
picked according to the major-mode."
  (interactive
   (let* ((buf (read-buffer "Buffer: " (current-buffer)))
          (key (with-current-buffer buf
                 (read-key-sequence (format "Run Key in %S: " buf))))
          (default-format
            (chunyang-format-command-on-key--default-format))
          (default-format-desc
            (car (rassq default-format chunyang-format-command-on-key--formats)))
          (format (if current-prefix-arg
                      (cdr (assoc
                            (completing-read "Format: "
                                             chunyang-format-command-on-key--formats
                                             nil t nil nil
                                             default-format-desc)
                            chunyang-format-command-on-key--formats))
                    default-format)))
     (list buf key format)))
  ;; In case calling from Lisp and FORMAT is omitted
  (setq format (or format (chunyang-format-command-on-key--default-format)))
  (let (key-name cmd result)
    (with-current-buffer (or buffer (current-buffer))
      (setq key-name (key-description key)
            cmd (key-binding key)))
    (setq result
          (cl-case format
            (org
             (format "~%s~ (~%s~)" key-name cmd))
            (markdown
             (format "`%s` (`%s`)" key-name cmd))
            (markdown-kbd
             (format "<kbd>%s</kbd> (`%s`)" key-name cmd))
            (emacs-lisp
             (format "%s (`%s')" key-name cmd))
            (default (format "'%s' ('%s')" key-name cmd))))
    (kill-new result)
    (message "Killed: %s" result)
    (insert result)))

;; According to my test ('M-x trace-function undefined'), when I type
;; some undefined key, the command `undefined' will be called.
;; (define-advice undefined (:after () do-something-when-key-binding-not-defined)
;;   "Serve as common-not-found hook.

;; At first, I want 'Did you mena xxx?', but I don't know how to implement."
;;   (message "%s is undefined"
;;            (propertize (key-description (this-single-command-keys))
;;                        'face 'error))
;;   )


;;; Remove advice in the Help buffer

(defun describe-function@advice-remove-button (&rest _r)
  "Add a button to remove advice."
  (require 'subr-x)
  (when-let ((buf (get-buffer "*Help*")))
    (with-current-buffer buf
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^:[-a-z]* advice: .\\(.*\\).$" nil t)
          (let* ((fun (nth 1 help-xref-stack-item))
                 (advice (intern (match-string 1)))
                 (button-fun (lambda (_)
                               (message "Removing %s from %s" advice fun)
                               ;; FIXME Not working for lambda, maybe
                               ;; https://emacs.stackexchange.com/questions/33020/how-can-i-remove-an-unnamed-advice
                               ;; can help
                               (advice-remove fun advice)
                               (save-excursion (revert-buffer nil t))))
                 (inhibit-read-only t))
            (insert " » ")
            (insert-text-button "Remove" 'action button-fun 'follow-link t)))))))

(advice-add 'describe-function :after #'describe-function@advice-remove-button)
;; The following is not needed since it calls `describe-function' (I guess)
;; (advice-add 'describe-symbol   :after #'describe-function@advice-remove-button)
(advice-add 'describe-key      :after #'describe-function@advice-remove-button)


;;; Hash Table

(defun chunyang-hash-table-to-alist (hash-table)
  (let ((alist '()))
    (maphash (lambda (k v) (push (cons k v) alist)) hash-table)
    (nreverse alist)))

;; (let ((ht (make-hash-table :test 'equal)))
;;   (puthash :one 1 ht)
;;   (puthash :two 2 ht)
;;   (chunyang-hash-table-to-alist ht))
;;      ⇒ ((:one . 1) (:two . 2))

(defun chunyang-make-hash-table-from-alist (alist &rest keyword-args)
  "Create and return a new hash table from ALIST.

KEYWORD-ARGS is same as `make-hash-table'."
  (loop with hash-table = (apply 'make-hash-table keyword-args)
        for (k . v) in alist
        do (puthash k v hash-table)
        finally return hash-table))

;; (chunyang-hash-table-to-alist
;;  (chunyang-make-hash-table-from-alist
;;   '(("one" . 1) ("two" . 2)) :test 'equal))
;;      ⇒ (("one" . 1) ("two" . 2))

(defun chunyang-plist-to-alist (plist)
  (loop for x on plist by #'cddr
        collect (cons (car x) (cadr x))))

;; (chunyang-plist-to-alist '(:one 1 :two 2))
;;      ⇒ ((:one . 1) (:two . 2))

(defun chunyang-alist-to-plist (alist)
  (loop for (k . v) in alist
        append (list k v)))

;; (chunyang-alist-to-plist '((:one . 1) (:two . 2)))
;;      ⇒ (:one 1 :two 2)


;;; Binary format in C-x C-e

(define-advice eval-expression-print-format (:around (old-fun value) binary)
  "Show (Binary, Octal, Hex, Char) for numbers."
  (let ((rtv (funcall old-fun value)))
    (if rtv
        (replace-regexp-in-string
         "(#o"
         (format "(%s, #o" (chunyang-format-as-binary value))
         rtv))))

(provide 'chunyang-elisp)

;;; chunyang-elisp.el ends here
