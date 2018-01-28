;;; prog-fill.el --- Smartly format lines to use vertical space. -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Matthew Carter <m@ahungry.com>

;; Author: Matthew Carter <m@ahungry.com>
;; Maintainer: Matthew Carter <m@ahungry.com>
;; URL: https://github.com/ahungry/color-theme-ahungry
;; Version: 0.0.1
;; Keywords: ahungry convenience c formatting
;; Package-Requires: ((emacs "25.1") (cl-lib "0.6.1"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Make

;;; Code:
(require 'cl-lib)

(defgroup prog-fill nil
  "Customizations for prog-fill."
  :tag "Prog Fill"
  :group 'applications)

;; Dynamically bind this when modes change
(defcustom prog-fill-method-separators '(or "->" ".")
  "The method separators for prog-fill method breaks.

In C, these would be `->' or `.'
In Javascript, these would be `.'
In PHP, these would be `->', `.', or `::'."
  :group 'prog-fill
  :type '(repeat (string :tag "rx or filters.")))

(defcustom prog-fill-arg-separators '(or ",")
  "The arg separators for prog-fill argument breaks.

In C, these would be `,'
In Lisp, these would be ` ' (space)"
  :group 'prog-fill
  :type '(repeat (string :tag "rx or filters.")))

(defcustom prog-fill-break-method-immediately-p nil
  "If methods in prog-fill calls should break immediately.

You may find in some modes you want to break right away on a method,
while others you do not, for instance in PHP it is common to use:

  $this->something
    ->anotherThing();

Whlie in JS you would usually see:

  object
    .something
    .anotherThing()

The default is nil, meaning it will only break on the second chained
call (not the first) - set to t to break on the first."
  :group 'prog-fill
  :type 'boolean)

(defvar prog-fill-floating-open-paren-p t
  "With this set to t, it will make a parenthesis `float' by itself.

Such as in PHP:

  $this->that(
    1,
    2
  );

If set to nil, it will *not* float, and will appear as:

  $this->that(1,
              2
  );

The default is t, floating parens."
  :group 'prog-fill
  :type 'boolean)

(defvar prog-fill-floating-close-paren-p t
  "With this set to t, it will make a parenthesis `float' by itself.

Such as in PHP:

  $this->that(
    1,
    2
  );

If set to nil, it will *not* float, and will appear as:

  $this->that(
    1,
    2);

The default is t, floating parens."
  :group 'prog-fill
  :type 'boolean)

(defvar prog-fill-auto-indent-p t
  "This controls the behavior of the auto-indent call.

If you disable it (set to nil) this package will not work well,
as it will assign the breaks without indenting them."
  :group 'prog-fill
  :type 'boolean)

(defun prog-fill ()
  "Split multi-argument call into one per line.

TODO: Handle string quotations (do not break them apart).
TODO: Handle different arg separators (Lisp style)."
  (interactive)
  (cl-flet ((re-next (reg) (re-search-forward reg nil t)))
    (save-excursion
      (save-restriction
        (goto-char (point-at-bol))
        (narrow-to-region (point) (point-at-eol))

        ;; Split args to methods on opening paren
        (goto-char (point-min))
        (while (re-next (rx "(" (group (not (any ")")))))
          (replace-match (rx "(\n" (backref 1))))

        ;; Split based on arglist
        (goto-char (point-min))
        (while (re-next  (rx-to-string `(group ,prog-fill-arg-separators)))
          (replace-match (rx (backref 1) ?\n)))

        ;; Split on closing paren
        (goto-char (point-min))
        (while (re-next ")")
          (replace-match "\n)"))

        ;; Split on nested parens/methods
        (goto-char (point-min))
        (while (re-next "))")
          (replace-match ")\n)"))

        ;; Split to multi-line chained method calls (keep first level bound)
        (goto-char (point-min))
        (while (re-next (rx-to-string
                         `(:
                           (group ,prog-fill-method-separators)
                           (group (zero-or-more any))
                           (group ,prog-fill-method-separators))))
          (replace-match (rx (backref 1) (backref 2) ?\n (backref 3))))

        ;; Split to multi-line chained method calls (keep first level unbound)
        (if prog-fill-break-method-immediately-p
            (progn                    ; This implies breaking on $this
              (goto-char (point-min))
              (while (re-next (rx-to-string
                               `(:
                                 (group ,prog-fill-method-separators))))
                (replace-match (rx ?\n (backref 1)))))

          (progn
            ;; Bring back up ending parens arrows
            (goto-char (point-min)) ; This implies breaking on $this->that
            (while (re-next (rx-to-string
                             `(:
                               ")" ?\n
                               (group ,prog-fill-method-separators))))
              (replace-match (rx ")" (backref 1))))))

        ;; Split multi-line
        (goto-char (point-min))
        (while (re-next (rx-to-string
                         `(:
                           ")"
                           (group ,prog-fill-method-separators))))
          (replace-match (rx ")" ?\n (backref 1))))

        ;; Bring back up closing parens
        (goto-char (point-min))
        (while (re-next (rx
                         "(" ?\n (0+ " ") ")"))
          (replace-match "()"))

        ;; Bring back up ALL closing parens
        (unless prog-fill-floating-close-paren-p
          (goto-char (point-min))
          (while (re-next (rx ?\n (0+ " ") ")"))
            (replace-match ")")))

        ;; Bring back up all the parens next lines
        (unless prog-fill-floating-open-paren-p
          (goto-char (point-min))
          (while (re-next (rx
                           "(" ?\n))
            (replace-match "(")))

        ;; Ensure no pure whitespace lines (what mode would want them?)
        (goto-char (point-min))
        (while (re-next (rx ?\n (0+ whitespace) eol))
          (replace-match ""))

        (when prog-fill-auto-indent-p
          (indent-region (point-min) (point-max)))

        (fill-paragraph)))))

(provide 'prog-fill)

;;; prog-fill.el ends here
