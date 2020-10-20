;;; Copyright © 2020 Marius Bakke <marius.bakke@usit.uio.no>
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(define-module (uio packages mreg)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system python)
  #:use-module ((guix licenses) #:select (gpl3+))
  #:use-module (gnu packages databases)
  #:use-module (gnu packages django)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz))

(define-public mreg
  (let ((commit "2257603514e025d12e27691d03638c1b7a735ddc")
        (revision "0"))
    (package
      (name "mreg")
      (version (git-version "0.0" revision commit))
      (home-page "https://github.com/unioslo/mreg")
      (source (origin
                (method git-fetch)
                (uri (git-reference (url home-page) (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "0hljw05j22kv4h9id13zng7fiprc8ki3rpqj485qlswry9vibkjv"))))
      (build-system python-build-system)
      (arguments
       '(#:phases (modify-phases %standard-phases
                    ;; No setup.py, so install manually.
                    (delete 'build)
                    (replace 'install
                      (lambda* (#:key inputs outputs #:allow-other-keys)
                        (let* ((out (assoc-ref outputs "out"))
                               (python (assoc-ref inputs "python"))
                               (site-packages (string-append out "/lib/python"
                                                             (python-version python)
                                                             "/site-packages")))
                          (copy-recursively "."
                                            (string-append site-packages "/mreg"))
                          #t)))
                    (add-before 'check 'start-postgresql
                      (lambda _
                        (mkdir-p "/tmp/db")
                        (invoke "initdb" "-D" "/tmp/db")
                        (invoke "pg_ctl" "-D" "/tmp/db" "-l" "/tmp/db.log" "start")

                        (invoke "psql" "-c" "CREATE EXTENSION citext;" "template1")
                        (invoke "psql" "-d" "postgres" "-c"
                                "CREATE DATABASE travisci;")))
                    (replace 'check
                      (lambda _
                        ;; Pretend to be the Travis CI system to piggy back on
                        ;; the test project defined in settings.py ...
                        (setenv "TRAVIS" "1")
                        ;; ... but ignore the user and port setting.
                        (substitute* "mregsite/settings.py"
                          ((".*'(USER|PORT)':.*")
                           ""))

                        (invoke "python" "manage.py" "test"))))))
      (native-inputs
       `(("postgresql" ,postgresql-11)))
      (inputs
       `(("python-django" ,python-django)
         ("python-djangorestframework" ,python-djangorestframework)
         ("python-django-auth-ldap" ,python-django-auth-ldap)
         ("python-django-logging-json" ,python-django-logging-json)
         ("python-django-netfields" ,python-django-netfields)
         ("python-django-url-filter" ,python-django-url-filter)
         ("gunicorn" ,gunicorn)
         ("python-idna" ,python-idna)
         ("python-psycopg2" ,python-psycopg2)))
      (synopsis "Machine inventory system")
      (description
       "@command{mreg} is a RESTful API for managing DNS zones, networks,
and servers.  Information about networks and devices are added through the
API, and the server can export DNS zone files and DHCP information for use
with servers.  Authentication using LDAP is supported, and permissions can
be delegated so that groups can manage only the networks they own.")
      (license gpl3+))))
