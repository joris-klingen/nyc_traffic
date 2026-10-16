# Simulated srts
#
# Real data: streets/calming/Speed_Reducer_Tracking_System__SRTS__20261014.csv, read with
# data.table::fread(nyc_latest('srts')); 61,062 rows, returned as a data.table.
# Speed Reducer Tracking System: requests for speed humps and cushions since the 1990s, one row
# per segment of a request with project code, status, request / study / installation / closed
# dates, denial reason, LION SegmentID, community board and From / To lat-lon.
# Columns: ProjectCode, GroupOwner, LocationDescription, Borough, ProjectStatus, NextStep,
# DateAdded, BCTSNum, CCUNum, RequestorLetterReplyDate, CBLetterRequestDate,
# CBLetterRecievedDate, OldSign, NewSign, MarkingsDate, InstallationDate, SecondStudyCode,
# ClosedDate, speedCushion, RequestDate, RequestorType, SegmentID, OnStreet, FromStreet,
# ToStreet, GeoBoroughName, LIONKey, FromLatitude, FromLongitude, ToLatitude, ToLongitude, OFT,
# CB, SegmentStatus, SegmentStatusDescription, DenialReason, NumSRProposed, TrafficDirection,
# TrafficDirectionDesc, OldSign1, NewSign1, OldSign2, NewSign2 (profiles/srts.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_srts(500)

sim_srts <- function(n = 1000, seed = NULL) sim_profile("srts", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_srts(10, seed = 1)))
}
