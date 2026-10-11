/**
 * BusinessClock backed by the platform BusinessHours class.
 */
public inherited sharing class PlatformBusinessClock implements BusinessClock {
  private static final Long MILLISECONDS_PER_MINUTE = 60000L;

  public Datetime addMinutes(
    Id businessHoursId,
    Datetime startTime,
    Integer minutes
  ) {
    return BusinessHours.add(
      businessHoursId,
      startTime,
      minutes * MILLISECONDS_PER_MINUTE
    );
  }

  public Integer minutesBetween(
    Id businessHoursId,
    Datetime startTime,
    Datetime endTime
  ) {
    return (BusinessHours.diff(businessHoursId, startTime, endTime) /
      MILLISECONDS_PER_MINUTE)
      .intValue();
  }
}
