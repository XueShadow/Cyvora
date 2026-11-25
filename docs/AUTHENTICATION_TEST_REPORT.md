# Cyvora Authentication Test Report

| Test | Expected | Actual | Status |
|---|---|---|---|
| Email/password validation | Invalid input rejected | Widget/unit tests passed | PASS |
| Sign-up metadata | Names, consent, policy versions sent | Source/presenter tests passed | PASS |
| MFA challenge UI | TOTP/SMS challenge states shown | Tests passed | PASS |
| Privileged MFA enforcement | AAL2 and factor required | Migration/source tests passed | PASS |
| Session auth gate | Redirects by auth/MFA state | Widget tests passed | PASS |
| Logout | Local session cleared | Source flow present; live session not tested | NOT TESTED |
| Real registration | Account and email confirmation created | No hosted credentials | BLOCKED |
| Real login/session | Valid session established | No hosted credentials | BLOCKED |
| Password reset email | Reset link delivered and consumed | No SMTP/project access | BLOCKED |
| Email verification | Confirmation required/enforced | No hosted Auth project | BLOCKED |
| Expired-session recovery | Invalid/expired session handled | Unit coverage only | NOT TESTED |
| Anonymous access | Private operations rejected | No live instance | BLOCKED |
