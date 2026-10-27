# Anonymize the Qualtrics export before it goes anywhere public.
#
# Input  (private, gitignored):  private/qualtrics_export.csv   the raw Qualtrics download, untouched
# Output (public, committed):    data/<id>/<id>_raw.csv         what replication-report.qmd reads
# Output (private, gitignored):  private/identifiers.csv        ResponseId -> Prolific ID, for payment only
#
# Run from the writeup/ folder:  Rscript anonymize.R            (Phase 1)
#                                Rscript anonymize.R replication-phase2
#
# The output keeps Qualtrics' layout (question-text row and ImportId row under the header) so
# read_phase() in the report reads it the same way. Two things change: identifying columns are
# dropped, and a same_referral column is added (computed here, because the report can no longer
# see the referral names).

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)
experiment_id <- if (length(args) >= 1) args[1] else "replication"

in_path  <- file.path("..", "private", "qualtrics_export.csv")
out_dir  <- file.path("..", "data", experiment_id)
out_path <- file.path(out_dir, paste0(experiment_id, "_raw.csv"))
id_path  <- file.path("..", "private", "identifiers.csv")

if (!file.exists(in_path)) stop("Put the raw Qualtrics export at ", normalizePath(file.path("..", "private"), mustWork = FALSE), "/qualtrics_export.csv")

raw <- read_csv(in_path, col_types = cols(.default = "c"), show_col_types = FALSE)
# Rows 1-2 are Qualtrics' question text and ImportId; keep them. Drop "Survey Preview" test
# responses (anything not collected as a real response, Status == "IP Address").
raw <- raw[seq_len(nrow(raw)) <= 2 | raw$Status == "IP Address", ]
is_data <- seq_len(nrow(raw)) > 2

# Referral-name comparison first, while the names are still here.
norm <- function(x) str_squish(str_to_lower(x))
raw$same_referral <- if_else(is_data, as.character(norm(raw$ref_name_1) == norm(raw$ref_name_2)), "")

# Payment link: real responses only, never published.
raw[is_data & raw$Status == "IP Address", ] |>
  select(ResponseId, PROLIFIC_PID) |>
  write_csv(id_path)

# Everything that identifies a person, or could: Prolific/Qualtrics ids, names of the people
# referred, free text (which can contain anything), timestamps, and IP/location fields.
identifying <- c("PID", "PROLIFIC_PID", "STUDY_ID", "SESSION_ID",
                 "ref_name_1", "ref_name_2", "ref_relation_1", "ref_relation_2", "feedback",
                 "StartDate", "EndDate", "RecordedDate",
                 "IPAddress", "RecipientLastName", "RecipientFirstName", "RecipientEmail",
                 "ExternalReference", "LocationLatitude", "LocationLongitude")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
raw |>
  select(-any_of(identifying)) |>
  write_csv(out_path)

message("Wrote ", out_path, " (", sum(is_data), " responses). Dropped: ",
        paste(intersect(identifying, names(raw)), collapse = ", "))
message("Wrote ", id_path, " (private). Check the output for anything identifying before committing.")
