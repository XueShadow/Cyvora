export type Json = string | number | boolean | null | {
  [key: string]: Json | undefined;
} | Json[];

export type Database = {
  "public": {
    Tables: {
      "alert_reads": {
        Row: {
          "alert_id": string;
          "read_at": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "alert_id": string;
          "read_at"?: string;
          "user_id": string;
        };
        Update: {
          "alert_id"?: string;
          "read_at"?: string;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "alert_reads_alert_id_fkey";
            columns: ["alert_id"];
            isOneToOne: false;
            referencedRelation: "alerts";
            referencedColumns: ["id"];
          },
        ];
      };
      "alerts": {
        Row: {
          "created_at": string;
          "detail": string;
          "family_id": string | null;
          "id": string;
          "report_id": string | null;
          "scan_record_id": string | null;
          "severity": string;
          "title": string;
          "user_id": string | null;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "detail": string;
          "family_id"?: string | null;
          "id"?: string;
          "report_id"?: string | null;
          "scan_record_id"?: string | null;
          "severity": string;
          "title": string;
          "user_id"?: string | null;
        };
        Update: {
          "created_at"?: string;
          "detail"?: string;
          "family_id"?: string | null;
          "id"?: string;
          "report_id"?: string | null;
          "scan_record_id"?: string | null;
          "severity"?: string;
          "title"?: string;
          "user_id"?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "alerts_family_id_fkey";
            columns: ["family_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "alerts_report_id_fkey";
            columns: ["report_id"];
            isOneToOne: false;
            referencedRelation: "scam_reports";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "alerts_scan_record_id_fkey";
            columns: ["scan_record_id"];
            isOneToOne: false;
            referencedRelation: "scan_records";
            referencedColumns: ["id"];
          },
        ];
      };
      "analysis_audit_logs": {
        Row: {
          "analysis_modules_status": NonNullable<Json>;
          "created_at": string;
          "engine_version": string;
          "event": string;
          "id": string;
          "metadata": NonNullable<Json>;
          "scan_record_id": string | null;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "analysis_modules_status"?: NonNullable<Json>;
          "created_at"?: string;
          "engine_version": string;
          "event": string;
          "id"?: string;
          "metadata"?: NonNullable<Json>;
          "scan_record_id"?: string | null;
          "user_id": string;
        };
        Update: {
          "analysis_modules_status"?: NonNullable<Json>;
          "created_at"?: string;
          "engine_version"?: string;
          "event"?: string;
          "id"?: string;
          "metadata"?: NonNullable<Json>;
          "scan_record_id"?: string | null;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "analysis_audit_logs_scan_record_id_fkey";
            columns: ["scan_record_id"];
            isOneToOne: false;
            referencedRelation: "scan_records";
            referencedColumns: ["id"];
          },
        ];
      };
      "analysis_module_results": {
        Row: {
          "category": string | null;
          "checked_at": string;
          "confidence": number;
          "details": NonNullable<Json>;
          "error_reason": string | null;
          "evidence": NonNullable<Json>;
          "evidence_kind": string;
          "id": string;
          "indicator_hash": string | null;
          "indicator_type": string | null;
          "module": string;
          "source": string;
          "status": string;
          "threat_scan_result_id": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "category"?: string | null;
          "checked_at"?: string;
          "confidence": number;
          "details"?: NonNullable<Json>;
          "error_reason"?: string | null;
          "evidence"?: NonNullable<Json>;
          "evidence_kind": string;
          "id"?: string;
          "indicator_hash"?: string | null;
          "indicator_type"?: string | null;
          "module": string;
          "source": string;
          "status": string;
          "threat_scan_result_id": string;
          "user_id": string;
        };
        Update: {
          "category"?: string | null;
          "checked_at"?: string;
          "confidence"?: number;
          "details"?: NonNullable<Json>;
          "error_reason"?: string | null;
          "evidence"?: NonNullable<Json>;
          "evidence_kind"?: string;
          "id"?: string;
          "indicator_hash"?: string | null;
          "indicator_type"?: string | null;
          "module"?: string;
          "source"?: string;
          "status"?: string;
          "threat_scan_result_id"?: string;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName:
              "analysis_module_results_threat_scan_result_id_fkey";
            columns: ["threat_scan_result_id"];
            isOneToOne: false;
            referencedRelation: "threat_scan_results";
            referencedColumns: ["id"];
          },
        ];
      };
      "community_threat_reports": {
        Row: {
          "category": string;
          "created_at": string;
          "id": string;
          "indicator_hash": string;
          "indicator_type": string;
          "reporter_id": string;
          "review_status": string;
          "reviewed_at": string | null;
          "reviewed_by": string | null;
        };
        ComputedFields: never;
        Insert: {
          "category": string;
          "created_at"?: string;
          "id"?: string;
          "indicator_hash": string;
          "indicator_type": string;
          "reporter_id": string;
          "review_status"?: string;
          "reviewed_at"?: string | null;
          "reviewed_by"?: string | null;
        };
        Update: {
          "category"?: string;
          "created_at"?: string;
          "id"?: string;
          "indicator_hash"?: string;
          "indicator_type"?: string;
          "reporter_id"?: string;
          "review_status"?: string;
          "reviewed_at"?: string | null;
          "reviewed_by"?: string | null;
        };
        Relationships: [];
      };
      "dataset_versions": {
        Row: {
          "approved_at": string | null;
          "approved_by": string | null;
          "created_at": string;
          "created_by": string | null;
          "evaluated_at": string | null;
          "evaluation_metrics": NonNullable<Json>;
          "evaluation_status": string;
          "example_count": number;
          "id": string;
          "release_status": string;
          "version_label": string;
          "version_sequence": number;
        };
        ComputedFields: never;
        Insert: {
          "approved_at"?: string | null;
          "approved_by"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "evaluated_at"?: string | null;
          "evaluation_metrics"?: NonNullable<Json>;
          "evaluation_status"?: string;
          "example_count": number;
          "id"?: string;
          "release_status"?: string;
          "version_label": string;
          "version_sequence"?: number;
        };
        Update: {
          "approved_at"?: string | null;
          "approved_by"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "evaluated_at"?: string | null;
          "evaluation_metrics"?: NonNullable<Json>;
          "evaluation_status"?: string;
          "example_count"?: number;
          "id"?: string;
          "release_status"?: string;
          "version_label"?: string;
          "version_sequence"?: number;
        };
        Relationships: [];
      };
      "detection_feedback": {
        Row: {
          "created_at": string;
          "feedback": string;
          "id": string;
          "scan_record_id": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "feedback": string;
          "id"?: string;
          "scan_record_id": string;
          "user_id": string;
        };
        Update: {
          "created_at"?: string;
          "feedback"?: string;
          "id"?: string;
          "scan_record_id"?: string;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "detection_feedback_scan_record_id_fkey";
            columns: ["scan_record_id"];
            isOneToOne: false;
            referencedRelation: "scan_records";
            referencedColumns: ["id"];
          },
        ];
      };
      "example_admin_overrides": {
        Row: {
          "admin_id": string;
          "created_at": string;
          "decision": string;
          "evidence_reference": string;
          "id": string;
          "submission_id": string;
        };
        ComputedFields: never;
        Insert: {
          "admin_id": string;
          "created_at"?: string;
          "decision": string;
          "evidence_reference": string;
          "id"?: string;
          "submission_id": string;
        };
        Update: {
          "admin_id"?: string;
          "created_at"?: string;
          "decision"?: string;
          "evidence_reference"?: string;
          "id"?: string;
          "submission_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "example_admin_overrides_submission_id_fkey";
            columns: ["submission_id"];
            isOneToOne: true;
            referencedRelation: "example_submissions";
            referencedColumns: ["id"];
          },
        ];
      };
      "example_submissions": {
        Row: {
          "content_hash": string;
          "content_type": string;
          "created_at": string;
          "id": string;
          "redacted_content": string;
          "reporter_id": string;
          "scan_record_id": string | null;
          "screening_result": NonNullable<Json>;
          "status": string;
          "status_note": string | null;
          "submitted_label": string;
          "updated_at": string;
        };
        ComputedFields: never;
        Insert: {
          "content_hash": string;
          "content_type": string;
          "created_at"?: string;
          "id"?: string;
          "redacted_content": string;
          "reporter_id": string;
          "scan_record_id"?: string | null;
          "screening_result"?: NonNullable<Json>;
          "status"?: string;
          "status_note"?: string | null;
          "submitted_label": string;
          "updated_at"?: string;
        };
        Update: {
          "content_hash"?: string;
          "content_type"?: string;
          "created_at"?: string;
          "id"?: string;
          "redacted_content"?: string;
          "reporter_id"?: string;
          "scan_record_id"?: string | null;
          "screening_result"?: NonNullable<Json>;
          "status"?: string;
          "status_note"?: string | null;
          "submitted_label"?: string;
          "updated_at"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "example_submissions_scan_record_id_fkey";
            columns: ["scan_record_id"];
            isOneToOne: false;
            referencedRelation: "scan_records";
            referencedColumns: ["id"];
          },
        ];
      };
      "example_verifications": {
        Row: {
          "created_at": string;
          "decision": string;
          "evidence_reference": string;
          "id": string;
          "notes": string | null;
          "reviewer_id": string;
          "submission_id": string;
          "verification_method": string;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "decision": string;
          "evidence_reference": string;
          "id"?: string;
          "notes"?: string | null;
          "reviewer_id": string;
          "submission_id": string;
          "verification_method": string;
        };
        Update: {
          "created_at"?: string;
          "decision"?: string;
          "evidence_reference"?: string;
          "id"?: string;
          "notes"?: string | null;
          "reviewer_id"?: string;
          "submission_id"?: string;
          "verification_method"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "example_verifications_submission_id_fkey";
            columns: ["submission_id"];
            isOneToOne: false;
            referencedRelation: "example_submissions";
            referencedColumns: ["id"];
          },
        ];
      };
      "families": {
        Row: {
          "created_at": string;
          "id": string;
          "name": string;
          "owner_id": string;
          "share_reports": boolean;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "id"?: string;
          "name": string;
          "owner_id": string;
          "share_reports"?: boolean;
        };
        Update: {
          "created_at"?: string;
          "id"?: string;
          "name"?: string;
          "owner_id"?: string;
          "share_reports"?: boolean;
        };
        Relationships: [];
      };
      "family_invites": {
        Row: {
          "accepted_at": string | null;
          "created_at": string;
          "expires_at": string;
          "family_id": string;
          "id": string;
          "invited_by": string;
          "invited_email": string;
          "token_hash": string;
        };
        ComputedFields: never;
        Insert: {
          "accepted_at"?: string | null;
          "created_at"?: string;
          "expires_at": string;
          "family_id": string;
          "id"?: string;
          "invited_by": string;
          "invited_email": string;
          "token_hash": string;
        };
        Update: {
          "accepted_at"?: string | null;
          "created_at"?: string;
          "expires_at"?: string;
          "family_id"?: string;
          "id"?: string;
          "invited_by"?: string;
          "invited_email"?: string;
          "token_hash"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "family_invites_family_id_fkey";
            columns: ["family_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id"];
          },
        ];
      };
      "family_members": {
        Row: {
          "family_id": string;
          "joined_at": string;
          "role": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "family_id": string;
          "joined_at"?: string;
          "role": string;
          "user_id": string;
        };
        Update: {
          "family_id"?: string;
          "joined_at"?: string;
          "role"?: string;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "family_members_family_id_fkey";
            columns: ["family_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id"];
          },
        ];
      };
      "intelligence_audit_logs": {
        Row: {
          "action": string;
          "actor_id": string | null;
          "created_at": string;
          "dataset_version_id": string | null;
          "id": number;
          "metadata": NonNullable<Json>;
          "submission_id": string | null;
        };
        ComputedFields: never;
        Insert: {
          "action": string;
          "actor_id"?: string | null;
          "created_at"?: string;
          "dataset_version_id"?: string | null;
          "id"?: never;
          "metadata"?: NonNullable<Json>;
          "submission_id"?: string | null;
        };
        Update: {
          "action"?: string;
          "actor_id"?: string | null;
          "created_at"?: string;
          "dataset_version_id"?: string | null;
          "id"?: never;
          "metadata"?: NonNullable<Json>;
          "submission_id"?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "intelligence_audit_logs_dataset_version_id_fkey";
            columns: ["dataset_version_id"];
            isOneToOne: false;
            referencedRelation: "dataset_versions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "intelligence_audit_logs_submission_id_fkey";
            columns: ["submission_id"];
            isOneToOne: false;
            referencedRelation: "example_submissions";
            referencedColumns: ["id"];
          },
        ];
      };
      "local_threat_indicators": {
        Row: {
          "active": boolean;
          "category": string;
          "created_at": string;
          "id": string;
          "indicator_hash": string;
          "indicator_type": string;
          "reviewed_by": string | null;
          "source_note": string | null;
        };
        ComputedFields: never;
        Insert: {
          "active"?: boolean;
          "category": string;
          "created_at"?: string;
          "id"?: string;
          "indicator_hash": string;
          "indicator_type": string;
          "reviewed_by"?: string | null;
          "source_note"?: string | null;
        };
        Update: {
          "active"?: boolean;
          "category"?: string;
          "created_at"?: string;
          "id"?: string;
          "indicator_hash"?: string;
          "indicator_type"?: string;
          "reviewed_by"?: string | null;
          "source_note"?: string | null;
        };
        Relationships: [];
      };
      "profiles": {
        Row: {
          "avatar_path": string | null;
          "first_name": string;
          "last_name": string;
          "updated_at": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "avatar_path"?: string | null;
          "first_name"?: string;
          "last_name"?: string;
          "updated_at"?: string;
          "user_id": string;
        };
        Update: {
          "avatar_path"?: string | null;
          "first_name"?: string;
          "last_name"?: string;
          "updated_at"?: string;
          "user_id"?: string;
        };
        Relationships: [];
      };
      "scam_intelligence_usage": {
        Row: {
          "request_count": number;
          "updated_at": string;
          "usage_date": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "request_count": number;
          "updated_at"?: string;
          "usage_date": string;
          "user_id": string;
        };
        Update: {
          "request_count"?: number;
          "updated_at"?: string;
          "usage_date"?: string;
          "user_id"?: string;
        };
        Relationships: [];
      };
      "scam_patterns": {
        Row: {
          "enabled": boolean;
          "id": string;
          "rule_id": string;
          "updated_at": string;
          "version": string;
          "weight": number;
        };
        ComputedFields: never;
        Insert: {
          "enabled"?: boolean;
          "id"?: string;
          "rule_id": string;
          "updated_at"?: string;
          "version": string;
          "weight": number;
        };
        Update: {
          "enabled"?: boolean;
          "id"?: string;
          "rule_id"?: string;
          "updated_at"?: string;
          "version"?: string;
          "weight"?: number;
        };
        Relationships: [];
      };
      "scam_reports": {
        Row: {
          "category": string;
          "created_at": string;
          "description": string;
          "family_id": string | null;
          "id": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "category": string;
          "created_at"?: string;
          "description": string;
          "family_id"?: string | null;
          "id"?: string;
          "user_id": string;
        };
        Update: {
          "category"?: string;
          "created_at"?: string;
          "description"?: string;
          "family_id"?: string | null;
          "id"?: string;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "scam_reports_family_id_fkey";
            columns: ["family_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id"];
          },
        ];
      };
      "scan_records": {
        Row: {
          "created_at": string;
          "id": string;
          "indicators": (string)[];
          "risk_level": string;
          "scan_type": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "id"?: string;
          "indicators"?: (string)[];
          "risk_level": string;
          "scan_type": string;
          "user_id": string;
        };
        Update: {
          "created_at"?: string;
          "id"?: string;
          "indicators"?: (string)[];
          "risk_level"?: string;
          "scan_type"?: string;
          "user_id"?: string;
        };
        Relationships: [];
      };
      "threat_provider_results": {
        Row: {
          "analysis_date": string | null;
          "cache_hit": boolean;
          "category": string | null;
          "checked_at": string;
          "classification": string;
          "confidence": number;
          "detection_stats": Json | null;
          "error_reason": string | null;
          "evidence": NonNullable<Json>;
          "evidence_kind": string;
          "id": string;
          "indicator_hash": string;
          "indicator_match": boolean;
          "indicator_type": string;
          "provider": string;
          "provider_status": string;
          "source": string;
          "status": string;
          "threat_scan_result_id": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "analysis_date"?: string | null;
          "cache_hit"?: boolean;
          "category"?: string | null;
          "checked_at"?: string;
          "classification": string;
          "confidence": number;
          "detection_stats"?: Json | null;
          "error_reason"?: string | null;
          "evidence"?: NonNullable<Json>;
          "evidence_kind"?: string;
          "id"?: string;
          "indicator_hash": string;
          "indicator_match"?: boolean;
          "indicator_type": string;
          "provider": string;
          "provider_status"?: string;
          "source"?: string;
          "status": string;
          "threat_scan_result_id": string;
          "user_id": string;
        };
        Update: {
          "analysis_date"?: string | null;
          "cache_hit"?: boolean;
          "category"?: string | null;
          "checked_at"?: string;
          "classification"?: string;
          "confidence"?: number;
          "detection_stats"?: Json | null;
          "error_reason"?: string | null;
          "evidence"?: NonNullable<Json>;
          "evidence_kind"?: string;
          "id"?: string;
          "indicator_hash"?: string;
          "indicator_match"?: boolean;
          "indicator_type"?: string;
          "provider"?: string;
          "provider_status"?: string;
          "source"?: string;
          "status"?: string;
          "threat_scan_result_id"?: string;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName:
              "threat_provider_results_threat_scan_result_id_user_id_fkey";
            columns: ["threat_scan_result_id", "user_id"];
            isOneToOne: false;
            referencedRelation: "threat_scan_results";
            referencedColumns: ["id", "user_id"];
          },
        ];
      };
      "threat_scan_results": {
        Row: {
          "ai_analysis": NonNullable<Json>;
          "analysis_classification": string | null;
          "analysis_confidence": number | null;
          "analysis_modules_status": NonNullable<Json>;
          "analysis_risk_level": string | null;
          "analysis_summary": string | null;
          "analyzed_at": string;
          "checked_at": string;
          "classification": string;
          "confidence": number;
          "confidence_reasons": NonNullable<Json>;
          "created_at": string;
          "engine_version": string;
          "evidence": NonNullable<Json>;
          "explanation": string;
          "id": string;
          "recommended_actions": NonNullable<Json>;
          "rule_analysis": NonNullable<Json>;
          "scan_record_id": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "ai_analysis"?: NonNullable<Json>;
          "analysis_classification"?: string | null;
          "analysis_confidence"?: number | null;
          "analysis_modules_status"?: NonNullable<Json>;
          "analysis_risk_level"?: string | null;
          "analysis_summary"?: string | null;
          "analyzed_at"?: string;
          "checked_at"?: string;
          "classification": string;
          "confidence": number;
          "confidence_reasons"?: NonNullable<Json>;
          "created_at"?: string;
          "engine_version"?: string;
          "evidence"?: NonNullable<Json>;
          "explanation": string;
          "id"?: string;
          "recommended_actions"?: NonNullable<Json>;
          "rule_analysis"?: NonNullable<Json>;
          "scan_record_id": string;
          "user_id": string;
        };
        Update: {
          "ai_analysis"?: NonNullable<Json>;
          "analysis_classification"?: string | null;
          "analysis_confidence"?: number | null;
          "analysis_modules_status"?: NonNullable<Json>;
          "analysis_risk_level"?: string | null;
          "analysis_summary"?: string | null;
          "analyzed_at"?: string;
          "checked_at"?: string;
          "classification"?: string;
          "confidence"?: number;
          "confidence_reasons"?: NonNullable<Json>;
          "created_at"?: string;
          "engine_version"?: string;
          "evidence"?: NonNullable<Json>;
          "explanation"?: string;
          "id"?: string;
          "recommended_actions"?: NonNullable<Json>;
          "rule_analysis"?: NonNullable<Json>;
          "scan_record_id"?: string;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "threat_scan_results_scan_record_id_fkey";
            columns: ["scan_record_id"];
            isOneToOne: true;
            referencedRelation: "scan_records";
            referencedColumns: ["id"];
          },
        ];
      };
      "trusted_training_examples": {
        Row: {
          "content_hash": string;
          "created_at": string;
          "dataset_version_id": string;
          "features": NonNullable<Json>;
          "id": string;
          "submission_id": string | null;
          "verified_label": string;
        };
        ComputedFields: never;
        Insert: {
          "content_hash": string;
          "created_at"?: string;
          "dataset_version_id": string;
          "features": NonNullable<Json>;
          "id"?: string;
          "submission_id"?: string | null;
          "verified_label": string;
        };
        Update: {
          "content_hash"?: string;
          "created_at"?: string;
          "dataset_version_id"?: string;
          "features"?: NonNullable<Json>;
          "id"?: string;
          "submission_id"?: string | null;
          "verified_label"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "trusted_training_examples_dataset_version_id_fkey";
            columns: ["dataset_version_id"];
            isOneToOne: false;
            referencedRelation: "dataset_versions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "trusted_training_examples_submission_id_fkey";
            columns: ["submission_id"];
            isOneToOne: true;
            referencedRelation: "example_submissions";
            referencedColumns: ["id"];
          },
        ];
      };
      "user_settings": {
        Row: {
          "family_activity_notifications": boolean;
          "push_notifications_enabled": boolean;
          "share_protection_status": boolean;
          "share_scan_results": boolean;
          "share_security_alerts": boolean;
          "updated_at": string;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "family_activity_notifications"?: boolean;
          "push_notifications_enabled"?: boolean;
          "share_protection_status"?: boolean;
          "share_scan_results"?: boolean;
          "share_security_alerts"?: boolean;
          "updated_at"?: string;
          "user_id": string;
        };
        Update: {
          "family_activity_notifications"?: boolean;
          "push_notifications_enabled"?: boolean;
          "share_protection_status"?: boolean;
          "share_scan_results"?: boolean;
          "share_security_alerts"?: boolean;
          "updated_at"?: string;
          "user_id"?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      "detection_feedback_daily": {
        Row: {
          "day": string | null;
          "engine_version": string | null;
          "feedback": string;
          "feedback_count": number | null;
          "reporter_count": number | null;
          "risk_level": string;
          "scan_type": string;
        };
        ComputedFields: never;
        Relationships: [];
      };
      "provider_health_daily": {
        Row: {
          "attempt_count": number | null;
          "average_duration_ms": number | null;
          "day": string | null;
          "provider": string | null;
          "provider_type": string | null;
          "status": string | null;
        };
        ComputedFields: never;
        Relationships: [];
      };
    };
    Functions: {
      "activate_trusted_dataset": {
        Args: { "target_actor_id": string; "target_version_id": string };
        Returns: undefined;
      };
      "are_family_members": {
        Args: { "first_user_id": string; "second_user_id": string };
        Returns: boolean;
      };
      "can_view_alert": {
        Args: { "target_alert_id": string };
        Returns: boolean;
      };
      "consume_family_invite": {
        Args: { "invite_token_hash": string; "joining_user_id": string };
        Returns: string;
      };
      "create_family_invite": {
        Args: {
          "p_expires_at": string;
          "p_family_id": string;
          "p_invited_by": string;
          "p_invited_email": string;
          "p_token_hash": string;
        };
        Returns: string;
      };
      "consume_scam_intelligence_quota": {
        Args: { "target_user_id": string };
        Returns: boolean;
      };
      "is_family_member": {
        Args: { "target_family_id": string };
        Returns: boolean;
      };
      "is_family_owner": {
        Args: { "target_family_id": string };
        Returns: boolean;
      };
      "prune_analysis_data": { Args: { "max_rows"?: number }; Returns: number };
      "record_threat_scan": {
        Args: {
          "target_analysis_modules": Json;
          "target_assessment": Json;
          "target_indicators": (string)[];
          "target_risk_level": string;
          "target_scan_type": string;
          "target_user_id": string;
        };
        Returns: string;
      };
      "stage_trusted_example": {
        Args: {
          "target_actor_id": string;
          "target_admin_override"?: boolean;
          "target_features": Json;
          "target_label": string;
          "target_override_evidence"?: string;
          "target_submission_id": string;
        };
        Returns: string;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema =
  DatabaseWithoutInternals[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof (
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Tables"
      ]
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Views"
      ]
    )
    : never = never,
> = DefaultSchemaTableNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals } ? (
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Views"
    ]
  )[TableName] extends {
    Row: infer R;
  } ? R
  : never
  : DefaultSchemaTableNameOrOptions extends
    keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[
      DefaultSchemaTableNameOrOptions
    ] extends {
      Row: infer R;
    } ? R
    : never
  : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Insert: infer I;
  } ? I
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I;
    } ? I
    : never
  : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Update: infer U;
  } ? U
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U;
    } ? U
    : never
  : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]][
      "Enums"
    ]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][
    EnumName
  ]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[
      PublicCompositeTypeNameOrOptions["schema"]
    ]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]][
    "CompositeTypes"
  ][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never;

export const Constants = {
  "public": {
    Enums: {},
  },
} as const;
