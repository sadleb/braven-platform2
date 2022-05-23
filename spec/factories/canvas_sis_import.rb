FactoryBot.define do
  # Represents an SisImport object returned from the canvas API
  factory :canvas_sis_import, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id)
    progress { '100' }
    workflow_state { SisImportStatus::WorkflowState::IMPORTED }
    started_at { "2020-10-14T16:25:10Z" }
    updated_at { "2020-10-14T17:25:10Z" }
    created_at { "2020-10-14T16:25:09Z" }

    factory :canvas_sis_import_running, class: Hash do
      workflow_state { SisImportStatus::WorkflowState::CREATED }
      progress { '0' }
    end

    factory :canvas_sis_import_failed, class: Hash do
      workflow_state { SisImportStatus::WorkflowState::FAILED_WITH_MESSAGES }
    end

    initialize_with { attributes.stringify_keys }
  end
end

# Example
#{
#    "add_sis_stickiness": null,
#    "batch_mode": null,
#    "batch_mode_term_id": null,
#    "change_threshold": null,
#    "clear_sis_stickiness": null,
#    "created_at": "2022-02-04T18:31:06Z",
#    "csv_attachments": [
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:23Z",
#            "display_name": "admins.csv",
#            "filename": "admins.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4288,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:23Z",
#            "size": 31,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:23Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4288/download?download_frd=1&verifier=fake",
#            "uuid": "GhdE16opd1WogVJGS5ym3KabLESiDjTXIhENVESX"
#        },
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:23Z",
#            "display_name": "sections.csv",
#            "filename": "sections.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4289,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:23Z",
#            "size": 33,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:23Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4289/download?download_frd=1&verifier=fake",
#            "uuid": "4MBIsTtTdfVEnWXBowL1rEt3dvV2AFiY1qyBLyey"
#        },
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:23Z",
#            "display_name": "users.csv",
#            "filename": "users.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4290,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:23Z",
#            "size": 51,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:23Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4290/download?download_frd=1&verifier=fake",
#            "uuid": "MHIgvFOKMJ6Mf6HUaHkEj0MG7IHY9BAQQ76PfPJr"
#        },
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:23Z",
#            "display_name": "enrollments.csv",
#            "filename": "enrollments.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4291,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:23Z",
#            "size": 56,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:23Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4291/download?download_frd=1&verifier=fake",
#            "uuid": "Tve66q8fF8DAkxWydg14ypII35gqjqYbk8alTjUP"
#        }
#    ],
#    "data": {
#        "completed_importers": [
#            "section",
#            "user"
#        ],
#        "counts": {
#            "abstract_courses": 0,
#            "accounts": 0,
#            "admins": 0,
#            "change_sis_ids": 0,
#            "courses": 0,
#            "enrollments": 0,
#            "error_count": 0,
#            "grade_publishing_results": 0,
#            "group_categories": 0,
#            "group_memberships": 0,
#            "groups": 0,
#            "logins": 0,
#            "sections": 5,
#            "terms": 0,
#            "user_observers": 0,
#            "users": 12,
#            "warning_count": 1,
#            "xlists": 0
#        },
#        "diffed_against_sis_batch_id": 146,
#        "diffed_attachment_ids": [
#            4293,
#            4294,
#            4295,
#            4296
#        ],
#        "downloadable_attachment_ids": [
#            4288,
#            4289,
#            4290,
#            4291,
#            4293,
#            4294,
#            4295,
#            4296
#        ],
#        "import_type": "instructure_csv",
#        "running_immediately": true,
#        "statistics": {
#            "AbstractCourse": {
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "Account": {
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "AccountUser": {
#                "created": 0,
#                "deleted": 3,
#                "restored": 0
#            },
#            "CommunicationChannel": {
#                "created": 0,
#                "deleted": 12,
#                "restored": 0
#            },
#            "Course": {
#                "concluded": 0,
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "CourseSection": {
#                "created": 0,
#                "deleted": 5,
#                "restored": 0
#            },
#            "Enrollment": {
#                "concluded": 0,
#                "created": 0,
#                "deactivated": 0,
#                "deleted": 43,
#                "restored": 0
#            },
#            "EnrollmentTerm": {
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "Group": {
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "GroupCategory": {
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "GroupMembership": {
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "Pseudonym": {
#                "created": 0,
#                "deleted": 4,
#                "restored": 0
#            },
#            "UserObserver": {
#                "created": 0,
#                "deleted": 0,
#                "restored": 0
#            },
#            "total_state_changes": 67
#        },
#        "supplied_batches": [
#            "section",
#            "user",
#            "enrollment",
#            "admin"
#        ]
#    },
#    "diff_row_count_threshold": null,
#    "diffed_against_import_id": null,
#    "diffed_csv_attachments": [
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:24Z",
#            "display_name": "admins.csv",
#            "filename": "admins.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4293,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:24Z",
#            "size": 31,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:24Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4293/download?download_frd=1&verifier=fake",
#            "uuid": "hsvDZ0UQJe0bugsEUvyGYG1iDkA10To21f7duTUV"
#        },
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:24Z",
#            "display_name": "sections.csv",
#            "filename": "sections.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4294,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:24Z",
#            "size": 461,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:24Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4294/download?download_frd=1&verifier=fake",
#            "uuid": "2pMVDmasv1CIDJg2AUx3Dshq5w3eXS4sR2SGhTPK"
#        },
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:24Z",
#            "display_name": "users.csv",
#            "filename": "users.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4295,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:24Z",
#            "size": 1473,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:24Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4295/download?download_frd=1&verifier=fake",
#            "uuid": "WoFNwHlf1lw01Z0wHDWd8BOSocgQ6TX75nNOMUwQ"
#        },
#        {
#            "content-type": "text/csv",
#            "created_at": "2022-02-04T18:31:24Z",
#            "display_name": "enrollments.csv",
#            "filename": "enrollments.csv",
#            "folder_id": null,
#            "hidden": false,
#            "hidden_for_user": false,
#            "id": 4296,
#            "lock_at": null,
#            "locked": false,
#            "locked_for_user": false,
#            "media_entry_id": null,
#            "mime_class": "file",
#            "modified_at": "2022-02-04T18:31:24Z",
#            "size": 56,
#            "thumbnail_url": null,
#            "unlock_at": null,
#            "updated_at": "2022-02-04T18:31:24Z",
#            "upload_status": "success",
#            "url": "https://braven.instructure.com/files/4296/download?download_frd=1&verifier=fake",
#            "uuid": "28rI3Kmxgb50Gz1ASDCjTmrPmKftDVEswE0iWsRD"
#        }
#    ],
#    "diffing_data_set_identifier": "brian-test-zipfile-sis-import1",
#    "diffing_drop_status": null,
#    "ended_at": "2022-02-04T18:31:28Z",
#    "errors_attachment": {
#        "content-type": "csv",
#        "created_at": "2022-02-04T18:31:35Z",
#        "display_name": "sis_errors_attachment_147.csv",
#        "filename": "160050000000000147_processing_warnings_and_errors2022-02-04+183135+UTC20220204-160315-1qdmppu.csv",
#        "folder_id": null,
#        "hidden": false,
#        "hidden_for_user": false,
#        "id": 4297,
#        "lock_at": null,
#        "locked": false,
#        "locked_for_user": false,
#        "media_entry_id": null,
#        "mime_class": "file",
#        "modified_at": "2022-02-04T18:31:35Z",
#        "size": 116,
#        "thumbnail_url": null,
#        "unlock_at": null,
#        "updated_at": "2022-02-04T18:31:35Z",
#        "upload_status": "success",
#        "url": "https://braven.instructure.com/files/4297/download?download_frd=1&verifier=fake",
#        "uuid": "r0vDlAlQcGRdgoJGKG2PqjnqqLwQpVkdZLgLRiaB"
#    },
#    "id": 147,
#    "multi_term_batch_mode": null,
#    "override_sis_stickiness": null,
#    "processing_warnings": [
#        [
#            "enrollments.csv",
#            "Couldn't generate diff: CSV headers do not match, cannot diff"
#        ]
#    ],
#    "progress": 100,
#    "skip_deletes": false,
#    "started_at": "2022-02-04T18:31:21Z",
#    "update_sis_id_if_login_claimed": true,
#    "updated_at": "2022-02-04T18:31:35Z",
#    "user": {
#        "created_at": "2020-02-19T09:29:34-05:00",
#        "id": 75,
#        "integration_id": null,
#        "login_id": "brian@bebraven.org",
#        "name": "Brian Sadler",
#        "short_name": "Brian Sadler",
#        "sis_import_id": null,
#        "sis_user_id": null,
#        "sortable_name": "Sadler, Brian"
#    },
#    "workflow_state": "imported_with_messages"
#}
