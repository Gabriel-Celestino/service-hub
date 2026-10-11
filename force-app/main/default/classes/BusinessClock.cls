/**
 * Time arithmetic in business time. Abstracted so that domain logic can be
 * unit tested with a simple wall clock instead of real Business Hours.
 */
public interface BusinessClock {
  Datetime addMinutes(Id businessHoursId, Datetime startTime, Integer minutes);
  Integer minutesBetween(
    Id businessHoursId,
    Datetime startTime,
    Datetime endTime
  );
}
