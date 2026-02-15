class FlashcardLogic {
  // Simple Box System / Leitner-ish
  // Retuns the next review date based on performance and current box/streak

  static DateTime calculateNextReview(DateTime now, int currentBox, String performance) {
    if (performance == 'again') {
      return now.add(const Duration(minutes: 10)); // Review soon
    }

    // Performance: 'hard', 'good', 'easy'
    int nextIntervalDays;
    
    switch (currentBox) {
      case 0: // New
        nextIntervalDays = 1;
        break;
      case 1:
        nextIntervalDays = 3;
        break;
      case 2:
        nextIntervalDays = 7;
        break;
      case 3:
        nextIntervalDays = 14;
        break;
      case 4:
        nextIntervalDays = 30;
        break;
      default:
        nextIntervalDays = 30; // Cap at 30 days for now
    }

    // Adjust based on rating
    if (performance == 'hard') {
      nextIntervalDays = (nextIntervalDays * 0.5).ceil(); // Penalty
      if (nextIntervalDays < 1) nextIntervalDays = 1;
    } else if (performance == 'easy') {
       nextIntervalDays = (nextIntervalDays * 1.5).ceil(); // Bonus
    }

    return now.add(Duration(days: nextIntervalDays));
  }
}
