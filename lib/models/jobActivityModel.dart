
class JobActivityModel {
  String? noneWorkActivity;
  String? sportsTypeDescription;
  String? jobType;
  String? goalOfFitness;
  int? sleepHoursAtNight;
  int? sleepHoursAtDay;
  int? exerciseHours;

  JobActivityModel();

  JobActivityModel.fromMap(Map? map){
    if(map == null){
      return;
    }

    jobType = map['job_type'];
    noneWorkActivity = map['none_work_activity'];
    sleepHoursAtNight = map['sleep_hours_at_night']?? 8;
    sleepHoursAtDay = map['sleep_hours_at_day']?? 0;
    exerciseHours = map['exercise_hours']?? 7;
    sportsTypeDescription = map['sport_types_description'];
    goalOfFitness = map['goal_of_fitness'];
  }

  Map toMap(){
    final map = {};

    map['job_type'] = jobType;
    map['none_work_activity'] = noneWorkActivity;
    map['sleep_hours_at_night'] = sleepHoursAtNight;
    map['sleep_hours_at_day'] = sleepHoursAtDay;
    map['exercise_hours'] = exerciseHours;
    map['sport_types_description'] = sportsTypeDescription;
    map['goal_of_fitness'] = goalOfFitness;

    return map;
  }

  void matchBy(JobActivityModel other){
    jobType = other.jobType;
    noneWorkActivity = other.noneWorkActivity;
    sleepHoursAtNight = other.sleepHoursAtNight;
    sleepHoursAtDay = other.sleepHoursAtDay;
    exerciseHours = other.exerciseHours;
    sportsTypeDescription = other.sportsTypeDescription;
    goalOfFitness = other.goalOfFitness;
  }
}