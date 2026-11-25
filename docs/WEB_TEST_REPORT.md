# Cyvora Web Test Report

| Test | Expected | Actual | Status |
|---|---|---|---|
| `flutter build web` | Artifact generated | `build/web` generated | PASS |
| Registration/auth UI visual | Responsive dark-violet layout | Browser snapshot showed auth screen | PASS |
| Compact/wide layout | No overflow | Widget tests passed | PASS |
| Browser routing | Initial route loads | Shared page snapshot showed app, then HTTP probe found server stopped | BLOCKED |
| Session persistence | Supabase session survives reload | No hosted credentials/live server | BLOCKED |
| Login/registration | Hosted auth succeeds | No hosted credentials | BLOCKED |
| Ollama unavailable behavior | Clear fallback state | Ollama explicitly excluded from routing | NOT TESTED |
| Screenshot selection | Browser picker works | Build/source only | NOT TESTED |
