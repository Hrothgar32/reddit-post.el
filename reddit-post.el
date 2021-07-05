;;; reddit-post.el --- A package to post blog articles to reddit -*- lexical-binding: t; -*-
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
(require 'cl-lib)
(require 's)
(require 'org)

(defvar reddit-post--version "0.0.1"
  "The current version of the package.")

(defvar reddit-post--oauth-client-id "t4eTUv2W8OxxdQ"
  "The client ID that links this up to the reddit.com OAuth endpoint.")

(defvar reddit-post--oauth-url
  "https://www.reddit.com/api/v1/authorize?client_id=%s&response_type=code&state=nil&redirect_uri=%s&duration=permanent&scope=vote,submit"
  "The OAuth URL/endpoint.")

(defvar reddit-post--oauth-access-token-uri
  "https://www.reddit.com/api/v1/access_token"
  "The OAuth access token URI (step 2, after user fills out code).")

(defvar reddit-post--submit-url "https://oauth.reddit.com/api/submit")

(defvar reddit-post--oauth-code ""
  "The OAuth code")

(defvar reddit-post--oauth-access-token "")
(defvar reddit-post--oauth-refresh-token "")

(defvar reddit-post--blog-base-url "")

(defvar reddit-post--oauth-redirect-uri
  "https://almoszediu.com"
  "The client ID that links this up to the reddit.com OAuth endpoint.")

(cl-defun reddit-post--oauth-fetch-callback-access-token (&rest data &allow-other-keys)
  "Callback to run when the oauth access fetch is complete."
  (let-alist (plist-get data :data)
    (unless (and .access_token .expires_in)
      (message "reddit-post: Failed to refresh the OAuth access token!")
      (error "reddit-post: Failed to refresh the OAuth access token!"))
    (setq reddit-post--oauth-access-token .access_token)
    ;; @todo Handle expires_in value (should be ~1 hour, so refresh before then)
    (message "reddit-post: Access token refreshed.")))

(defun reddit-post--oauth-fetch-access-token ()
  "Make a request for a new OAuth access token using the permanent refresh token."
  (request-response-data
   (request reddit-post--oauth-access-token-uri
            :complete #'reddit-post--oauth-fetch-callback-access-token
            :data (format "grant_type=refresh_token&refresh_token=%s"
                          reddit-post--oauth-refresh-token)
            :sync nil
            :type "POST"
            :parser #'json-read
            :headers `(("User-Agent" . "reddit-post")
                       ;; This is just the 'client_id:' base64'ed
                       ("Authorization" . ,(format "Basic %s" (base64-encode-string (format "%s:" reddit-post--oauth-client-id))))))))

(defun reddit-post--oauth-browser-fetch ()
  "Open the user's browser to the endpoint to get the OAuth token."
  (message (format "For OAuth (md4rd) opening browser to: %s" (reddit-post--oauth-build-url)))
  (browse-url
   (reddit-post--oauth-build-url)))

(cl-defun reddit-post--oauth-fetch-callback (&rest data &allow-other-keys)
  "Callback to run when the oauth code fetch is complete."
  (let-alist (plist-get data :data)
    (unless (and .access_token .refresh_token .expires_in)
      (message "Failed to fetch OAuth access_token and refresh_token values!")
      (error "Failed to fetch OAuth access_token and refresh_token values!"))
    (setq reddit-post--oauth-access-token .access_token)
    (setq reddit-post--oauth-refresh-token .refresh_token)
    ;; @todo Handle expires_in value (should be ~1 hour, so refresh before then)
    (message "Tokens set - consider adding reddit-post--oauth-access-token and reddit-post--oauth-refresh-token values to your init file to avoid signing in again in the future sessions.")))

(defun reddit-post--oauth-build-url ()
  "Generate the URL based on our parameters."
  (format reddit-post--oauth-url
          reddit-post--oauth-client-id
          reddit-post--oauth-redirect-uri))

(defun reddit-post--oauth-fetch-authorization-token ()
  "Make the initial code request for OAuth."
  (request-response-data
   (request reddit-post--oauth-access-token-uri
            :complete #'reddit-post--oauth-fetch-callback
            :data (format "grant_type=authorization_code&code=%s&redirect_uri=%s"
                          reddit-post--oauth-code
                          reddit-post--oauth-redirect-uri)
            :sync nil
            :type "POST"
            :parser #'json-read
            :headers `(("User-Agent" . "post.el")
                       ;; This is just the 'client_id:' base64'ed
                       ("Authorization" . ,(format "Basic %s" (base64-encode-string (format "%s:" reddit-post--oauth-client-id))))))))

(defun reddit-post--oauth-set-code (code)
  "Set the authorization CODE for OAuth (necessary to request the bearer token)."
  (interactive "sPlease enter the code you received from the browser: ")
  (setq reddit-post--oauth-code (s-trim code)))

(defvar blogpost-title "")

(defun reddit-post--get-blogpost-name()
  "Get the title of the blogpost."
  (search-forward "EXPORT_FILE_NAME: ")
  (push-mark (point) nil t)
  (end-of-line)
  (copy-region-as-kill nil nil t)
  (substring-no-properties (current-kill 0)))

(defun reddit-post--construct-post-title (blogpost-name-string)
 (let* ((blogpost-name (split-string blogpost-name-string "-")))
        (while (> (safe-length blogpost-name) 0)
        (if (= (safe-length blogpost-name) 1 )
        (setq blogpost-title(concat blogpost-title (capitalize(pop blogpost-name))))
        (setq blogpost-title(concat blogpost-title (capitalize(pop blogpost-name))" "))))))

(defun reddit-post--post-article (subreddit)
  (interactive (list (read-string "Name of subreddit: ")))
  (let* ((blogpost-name (reddit-post--get-blogpost-name))
         (blogpost-link (concat reddit-post--blog-base-url blogpost-name)))
        (reddit-post--construct-post-title blogpost-name)
        (request-response-data
                (request reddit-post--submit-url
                :complete nil
                :data (format "sr=%s&title=%s&url=%s" subreddit blogpost-title blogpost-link)
                :sync nil
                :type "POST"
                :parser #'json-read
                :headers `(("User-Agent" . "post.el")
                                ("Authorization" . ,(format "bearer %s" reddit-post--oauth-access-token)))))
        (setq blogpost-title "")
        (org-backward-paragraph 2)))

;;;###autoload
(defun reddit-post--login ()
  "Sign into the reddit system via OAuth, to allow use of authenticated endpoints."
  (interactive)
  (reddit-post--oauth-browser-fetch)
  (call-interactively #'reddit-post--oauth-set-code)
  (reddit-post--oauth-fetch-authorization-token))

(provide 'reddit-post.el)
;;; reddit-post.el ends here
