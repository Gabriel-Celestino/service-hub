@IsTest
private class SlaStatusSummarizerTest {
  private static SLA_Milestone__c openMilestone(String status) {
    return new SLA_Milestone__c(Status__c = status);
  }

  private static SLA_Milestone__c completedMilestone(String status) {
    return new SLA_Milestone__c(
      Status__c = status,
      Completed_At__c = System.now()
    );
  }

  private static String summarize(List<SLA_Milestone__c> milestones) {
    return SlaStatusSummarizer.summarize(milestones);
  }

  @IsTest
  static void noMilestonesLeavesCaseUnchanged() {
    Assert.isNull(summarize(null), 'Null list');
    Assert.isNull(summarize(new List<SLA_Milestone__c>()), 'Empty list');
  }

  @IsTest
  static void anyBreachWins() {
    Assert.areEqual(
      SlaConstants.SLA_BREACHED,
      summarize(
        new List<SLA_Milestone__c>{
          completedMilestone(SlaConstants.MILESTONE_BREACHED),
          openMilestone(SlaConstants.MILESTONE_OPEN)
        }
      ),
      'A completed breach marks the case as breached'
    );
  }

  @IsTest
  static void atRiskBeatsRunningAndPaused() {
    Assert.areEqual(
      SlaConstants.SLA_AT_RISK,
      summarize(
        new List<SLA_Milestone__c>{
          openMilestone(SlaConstants.MILESTONE_AT_RISK),
          openMilestone(SlaConstants.MILESTONE_OPEN)
        }
      ),
      'At risk is worse than on track'
    );
  }

  @IsTest
  static void runningClockMeansOnTrack() {
    Assert.areEqual(
      SlaConstants.SLA_ON_TRACK,
      summarize(
        new List<SLA_Milestone__c>{
          openMilestone(SlaConstants.MILESTONE_OPEN),
          openMilestone(SlaConstants.MILESTONE_PAUSED)
        }
      ),
      'Any running clock means on track'
    );
  }

  @IsTest
  static void onlyPausedClocksMeansPaused() {
    Assert.areEqual(
      SlaConstants.SLA_PAUSED,
      summarize(
        new List<SLA_Milestone__c>{
          completedMilestone(SlaConstants.MILESTONE_MET),
          openMilestone(SlaConstants.MILESTONE_PAUSED)
        }
      ),
      'All open milestones paused'
    );
  }

  @IsTest
  static void allMetMeansMet() {
    Assert.areEqual(
      SlaConstants.SLA_MET,
      summarize(
        new List<SLA_Milestone__c>{
          completedMilestone(SlaConstants.MILESTONE_MET),
          completedMilestone(SlaConstants.MILESTONE_MET)
        }
      ),
      'Every milestone met'
    );
  }
}
