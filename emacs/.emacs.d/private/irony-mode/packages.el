(setq irony-mode-packages
  '(irony
    company-irony
    flycheck-irony))

(setq irony-mode-excluded-packages
  '(auto-complete-clang))

(defun irony-mode/init-irony ()
  (use-package irony
    :defer t
    :init
    (progn
      (add-hook 'c++-mode-hook 'irony-mode)
      (add-hook 'c-mode-hook 'irony-mode)
      (add-hook 'objc-mode-hook 'irony-mode)
      (add-hook 'irony-mode-hook
                (lambda ()
                  (define-key irony-mode-map [remap completion-at-point]
                    'irony-completion-at-point-async)
                  (define-key irony-mode-map [remap complete-symbol]
                    'irony-completion-at-point-async)))
      (add-hook 'irony-mode-hook 'irony-cdb-autosetup-compile-options)
      (spacemacs|diminish irony-mode " Ⓘ" " I"))))

(defun irony-mode/init-company-irony ()
  (use-package company-irony
    :defer t
    :init
    (progn
      (eval-after-load 'company
        '(add-to-list 'company-backends 'company-irony))
      (add-hook 'irony-mode-hook 'company-irony-setup-begin-commands)
      (add-hook 'irony-mode-hook 'company-mode))))

(defun irony-mode/init-flycheck-irony ()
  (use-package flycheck-irony
    ;; :defer t                            ; fix this ???
    :init
    (progn
      (eval-after-load 'flycheck
        '(add-to-list 'flycheck-checkers 'irony))
      (add-hook 'irony-mode-hook 'flycheck-mode))))

