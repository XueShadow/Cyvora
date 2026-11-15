alter table public.analysis_module_results
  drop constraint if exists analysis_module_results_module_check,
  add constraint analysis_module_results_module_check
    check (module in (
      'url_structure', 'domain_dns', 'ssl_tls', 'redirect_analysis',
      'suspicious_patterns', 'local_indicator_database', 'community_reports',
      'external_threat_intelligence', 'scam_pattern_recognition'
    ));

notify pgrst, 'reload schema';
