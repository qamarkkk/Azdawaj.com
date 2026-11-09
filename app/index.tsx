import React, { useState } from "react";
import { Alert, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View } from "react-native";

const profiles = [
  { name: "Ayesha", age: 25, city: "Lahore", about: "Enjoys books, family time and travelling." },
  { name: "Fatima", age: 27, city: "Islamabad", about: "Interested in education, nature and meaningful conversations." },
  { name: "Maryam", age: 24, city: "Karachi", about: "Looking for a respectful, serious connection." }
];

export default function HomeScreen() {
  const [screen, setScreen] = useState("welcome");
  const [name, setName] = useState("");
  const [age, setAge] = useState("");
  const [city, setCity] = useState("");
  const [about, setAbout] = useState("");
  const [index, setIndex] = useState(0);
  const [likes, setLikes] = useState(0);
  const profile = profiles[index % profiles.length];

  function continueProfile() {
    const n = Number(age);
    if (!name.trim() || !city.trim() || !Number.isInteger(n)) {
      Alert.alert("Complete your details", "Enter your name, age and city.");
      return;
    }
    if (n < 18) {
      Alert.alert("Adults only", "AZDAWAJ.COM is for people aged 18 and above.");
      return;
    }
    setScreen("discover");
  }

  return <SafeAreaView style={s.safe}>
    <ScrollView contentContainerStyle={s.container}>
      <Text style={s.brand}>AZDAWAJ<Text style={s.pink}>.COM</Text></Text>
      <Text style={s.tagline}>Connect hearts. Build meaningful relationships.</Text>
      {screen === "welcome" && <View style={s.card}>
        <Text style={s.heart}>♥</Text>
        <Text style={s.heading}>A meaningful connection starts here</Text>
        <Text style={s.body}>A Pakistan-focused matchmaking experience built around respect, compatibility and genuine intentions.</Text>
        <TouchableOpacity style={s.primary} onPress={() => setScreen("profile")}><Text style={s.primaryText}>Get started</Text></TouchableOpacity>
        <Text style={s.note}>Adults aged 18+ only</Text>
      </View>}
      {screen === "profile" && <View style={s.card}>
        <Text style={s.heading}>Create your profile</Text>
        <TextInput style={s.input} placeholder="Your name" value={name} onChangeText={setName}/>
        <TextInput style={s.input} placeholder="Age (18+)" value={age} onChangeText={setAge} keyboardType="number-pad"/>
        <TextInput style={s.input} placeholder="City in Pakistan" value={city} onChangeText={setCity}/>
        <TextInput style={[s.input,s.multi]} placeholder="A little about yourself (optional)" value={about} onChangeText={setAbout} multiline/>
        <TouchableOpacity style={s.primary} onPress={continueProfile}><Text style={s.primaryText}>Continue</Text></TouchableOpacity>
        <TouchableOpacity onPress={() => setScreen("welcome")}><Text style={s.link}>Back</Text></TouchableOpacity>
      </View>}
      {screen === "discover" && <View style={s.card}>
        <Text style={s.eyebrow}>DISCOVER</Text>
        <Text style={s.heading}>Meet people with serious intentions</Text>
        <View style={s.avatar}><Text style={s.avatarText}>{profile.name[0]}</Text></View>
        <Text style={s.person}>{profile.name}, {profile.age}</Text>
        <Text style={s.city}>{profile.city}</Text>
        <Text style={s.body}>{profile.about}</Text>
        <View style={s.actions}>
          <TouchableOpacity style={s.pass} onPress={() => setIndex(index + 1)}><Text>Pass</Text></TouchableOpacity>
          <TouchableOpacity style={s.primary} onPress={() => {setLikes(likes + 1);setIndex(index + 1);}}><Text style={s.primaryText}>Like ♥</Text></TouchableOpacity>
        </View>
        <Text style={s.note}>Demo profiles only — no real users or matching yet.</Text>
        <Text style={s.note}>Demo likes: {likes}</Text>
      </View>}
      <Text style={s.footer}>Respect • Privacy • Genuine connections</Text>
    </ScrollView>
  </SafeAreaView>;
}

const s = StyleSheet.create({
  safe:{flex:1,backgroundColor:"#fff7fa"},
  container:{flexGrow:1,padding:22,justifyContent:"center"},
  brand:{textAlign:"center",fontSize:30,fontWeight:"900",color:"#651747",letterSpacing:1},
  pink:{color:"#d64c83"},
  tagline:{textAlign:"center",color:"#765b6b",marginTop:7,marginBottom:28,fontSize:13},
  card:{backgroundColor:"#fff",borderRadius:24,padding:24,shadowColor:"#4a1733",shadowOpacity:.08,shadowRadius:18,elevation:3},
  heart:{fontSize:58,color:"#c52d70",textAlign:"center",marginBottom:12},
  heading:{fontSize:24,lineHeight:31,color:"#351326",fontWeight:"800",textAlign:"center",marginBottom:16},
  body:{color:"#765b6b",fontSize:15,lineHeight:23,textAlign:"center",marginBottom:20},
  primary:{backgroundColor:"#9b2861",padding:15,borderRadius:14,alignItems:"center",justifyContent:"center",flex:1,marginTop:8},
  primaryText:{color:"#fff",fontSize:16,fontWeight:"700"},
  note:{textAlign:"center",color:"#947d8b",fontSize:12,marginTop:16},
  input:{borderWidth:1,borderColor:"#ead9e2",backgroundColor:"#fffafd",borderRadius:12,padding:14,marginBottom:12,fontSize:15,color:"#351326"},
  multi:{minHeight:88,textAlignVertical:"top"},
  link:{textAlign:"center",color:"#9b2861",fontWeight:"700",marginTop:18},
  eyebrow:{color:"#c0447c",fontWeight:"800",textAlign:"center",letterSpacing:2,marginBottom:8},
  avatar:{width:112,height:112,borderRadius:56,backgroundColor:"#f7d5e4",alignSelf:"center",alignItems:"center",justifyContent:"center",marginVertical:14},
  avatarText:{color:"#8c2057",fontSize:42,fontWeight:"800"},
  person:{color:"#351326",fontSize:22,fontWeight:"800",textAlign:"center"},
  city:{color:"#a04472",textAlign:"center",marginTop:4,marginBottom:14},
  actions:{flexDirection:"row",gap:12,marginTop:8},
  pass:{flex:1,padding:15,borderRadius:14,borderWidth:1,borderColor:"#d8bdcb",alignItems:"center",justifyContent:"center",marginTop:8},
  footer:{textAlign:"center",color:"#a58d9b",marginTop:25,fontSize:12}
});