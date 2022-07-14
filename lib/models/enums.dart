
enum NodeNames {
  height_node,
  weight_node,
  chest_node,
  neck_node,
  abdominal_node,
  right_arm_node,
  left_arm_node,
  right_contracted_arm_node,
  left_contracted_arm_node,
  right_wrist_node,
  left_wrist_node,
  waist_node,
  hip_node,
  right_thigh_node,
  left_thigh_node,
  right_ankle_node,
  left_ankle_node,

  side_photo,
  front_photo,
  back_photo,
  experiment_photo,
  body_photo,
  body_analysis_photo,
}

extension NodeNamesEx on NodeNames {
  NodeNames? byName(String name){
    for(var i in NodeNames.values){
      if(i.name == name){
        return i;
      }
    }
  }
}
///===================================================================================================
enum UserDataType {
  personal,
  country,
  currency,
  profileImage,
  userName,
  userNamePassword,
  mobileNumber,
  sportsEquipment,
  healthCondition,
  jobActivity,
  fitnessStatus,
  lastTouch,
  bankCard,
}
//cityAndCountry,