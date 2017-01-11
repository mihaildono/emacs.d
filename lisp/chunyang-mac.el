;;; chunyang-mac.el --- macOS Supports  -*- lexical-binding: t; -*-

;; Copyright (C) 2015, 2017  Chunyang Xu

;; Author: Chunyang Xu <mail@xuchunyang.me>

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

;; Some macOS supports

;;; Code:


;;; Working with Terminal.app

(defun chunyang-mac-escape-quote (s)
  "Convert \" in S into \\\"."
  (replace-regexp-in-string "\"" "\\\\\"" s))

(defun chunyang-mac-Terminal-send-string (s)
  "Run STR in Terminal.app."
  (do-applescript
   (format (concat
            "tell application \"Terminal\"\n"
            "activate\n"
            "do script \"%s\" in window 1\n"
            "end tell")
           (chunyang-mac-escape-quote s))))

(defun chunyang-mac-Terminal-send-region (start end)
  "Send the current region to Terminal.app."
  (interactive "r")
  (chunyang-mac-Terminal-send-string (buffer-substring start end)))

(defun chunyang-mac-Terminal-cd (dir)
  "Open Terminal.app and cd to DIR in it."
  (interactive (list (if current-prefix-arg
                         (read-directory-name "cd to: ")
                       default-directory)))
  (chunyang-mac-Terminal-send-string (format "cd '%s'" dir)))

(provide 'chunyang-mac)
;;; chunyang-mac.el ends here