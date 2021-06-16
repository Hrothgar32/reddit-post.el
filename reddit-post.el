;;; reddit-post.el --- A package for me to post blog articles to reddit -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2021 Almos-Agoston Zediu
;;
;; Author: Almos-Agoston Zediu <https://github.com/hrothgar32>
;; Maintainer: Almos-Agoston Zediu <zold.almos@gmail.com>
;; Version: 0.0.1
;; Keywords: Symbol’s value as variable is void: finder-known-keywords
;; Homepage: https://github.com/hrothgar32/reddit-post
;; Package-Requires: ((emacs "24.3") (request "0.3.0"))
;;
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
;;
;;; Commentary:
;;
;; A package for posting my blog articles from Emacs to reddit.
;;
;;
;;; Code:

(require 'request)
(require 'json)

(defvar reddit-post--version "0.0.1"
  "The current version of the package.")

(defvar reddit-post--oauth-client-id "pTkXgOSqUZFCeg"
  "The client ID that links this up to the reddit.com OAuth endpoint.")

(defvar blog-base-url "https://blog.almoszediu.com/posts/")

(provide 'reddit-post)
;;; reddit-post.el ends here
