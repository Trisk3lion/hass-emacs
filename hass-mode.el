;;; hass-mode.el --- Home Assistant autocompletion of entity names for GNU Emacs

;; Author: Greg J. Badros  <badros@gmail.com>
;; Url: https://github.com/gjbadros/hass-emacs
;; Package-Version: 0.1
;; Version: 0.1
;; Package-Requires: ((emacs "24.4") (json "1.5") (request "0.3.2") (auto-complete "1.5.1"))
;; Keywords: smarthome

;;; Use at your own risk -- see LICENSE

;;; See:
;;; https://www.emacswiki.org/emacs/InstallingPackages
;;; for details on how to get use-package to work
;;;
;;; Put these in hass-mode-secrets.el
;;; (defvar HASS_BEARER_TOKEN "xxx")
;;; (defvar HASS_URL_PREFIX "https://....")  ;; through the hostname and port only
;;;
;;; Remember to call M-x auto-complete-mode on the YAML buffer
;;; in order to turn auto-completion on.

;;; Code:

;;;; Require

(require 'auto-complete)
(require 'request)
(require 'json)


(if (file-readable-p "hass-mode-secrets.el")
    (load-file "./hass-mode-secrets.el"))

(defvar hass-entities)

(defun include-dots-in-symbol-syntax-table ()
  (with-syntax-table (syntax-table)
    (modify-syntax-entry ?. "_")))

(defun dotted-symbol-at-point ()
  (with-syntax-table (make-syntax-table (syntax-table))
    (modify-syntax-entry ?. "_")
    (thing-at-point 'symbol)))

(defvar hass-api-states-json '())

(defun hass-setup-completion-from-file (filename)
  (interactive "fAPI States filename: ")
  (hass-setup-completion filename))

(defun process-api-states ()
  (setq hass-entities
        (mapcar (lambda (a)
                  (cdr (assoc 'entity_id a)))
                hass-api-states-json))
  (message "Got %S entities" (length hass-entities))
  (setq ac-user-dictionary hass-entities)
  (setq ac-sources '(ac-source-dictionary ac-source-words-in-same-mode-buffers))
  (ac-clear-dictionary-cache))


(defun hass-setup-completion (&optional from-file)
  "Setup autocompletion for home assistant in the current buffer.
FROM-FILE is the name of a filename that has the JSON contents of /api/states
from the server, or put the secrets in the file hass-mode-secrets.el
in order to talk to the live server."
  (interactive)
  (if from-file
      (progn
        (setq hass-api-states-json (json-read-file from-file))
        (process-api-states))
    (request
      (concat HASS_URL_PREFIX "/api/states")
      :headers `(("Authorization" . ,(concat "Bearer " HASS_BEARER_TOKEN))
                 ("Content-Type" . "application/json"))
      :parser 'json-read
      :error (cl-function
              (lambda (&rest args &key error-thrown &allow-other-keys)
                (message "Got error: %S" error-thrown)))
      :success (cl-function
                (lambda (&key data response &allow-other-keys)
                  (if (not (eq (request-response-status-code response) 200))
                      (message "Got error code: %S" (request-response-status-code response))
                    (setq hass-api-states-json data)
                    (process-api-states))))
      :timeout 8
      ))

  (include-dots-in-symbol-syntax-table)
  )
