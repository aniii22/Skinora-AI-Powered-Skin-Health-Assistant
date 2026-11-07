import 'package:flutter/foundation.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// The day shown on the Routine screen (week strip and plan card share it).
final ValueNotifier<DateTime> selectedRoutineDay = ValueNotifier<DateTime>(
  _today(),
);

/// One thought per day, in the chosen language ('en', 'hi' or 'mr').
/// The same date always gives the same thought, so past days can be revisited.
String dailyThought(DateTime day, String lang) {
  final list = lang == 'hi' ? _hi : (lang == 'mr' ? _mr : _en);
  final d = DateTime(day.year, day.month, day.day);
  final n = d.difference(DateTime(d.year, 1, 1)).inDays;
  return list[n % list.length];
}

const List<String> _en = [
  "Skin doesn't change in a day. A little each day is enough.",
  "Consistency beats expensive products, every single time.",
  "Today's water is tomorrow's glow.",
  "Your skin is listening. Speak to it gently.",
  "Sunscreen is the best anti-aging step. Never skip it.",
  "Small steps, big results. Just begin.",
  "Rest is part of the routine. Sleep is skincare too.",
  "Less is more. Introduce one new product at a time.",
  "Be patient. Real skin changes take 4 to 6 weeks.",
  "Glow comes from within: water, sleep and happiness.",
  "Don't compare your skin to filters. Real skin has texture.",
  "Take 10 minutes for yourself today. You deserve it.",
  "Healthy skin barrier, happy skin.",
  "Progress, not perfection.",
  "Missed a day? No worries. Start again tomorrow.",
  "Treat your skin like a friend, not a project.",
  "Kind to skin, kind to mind.",
  "Hydrated skin is happy skin. Sip, sip, sip.",
  "Skincare is self-respect in small daily doses.",
  "What you do today shows on your skin in three months.",
  "Don't chase trends. Follow what your skin needs.",
  "Smile more. It's the cheapest glow-up.",
  "Pimples are temporary. Be gentle, don't pick.",
  "Slow routine, calm mind, clear skin.",
  "You are beautiful as you are. Skincare is simply care.",
  "Wash gently, moisturise well, protect always.",
  "Your future skin will thank you for today.",
  "Have a glass of water right now. Your skin will thank you.",
  "Stress less, glow more.",
  "Every day is a fresh page. Make it a glowing one.",
];

const List<String> _hi = [
  "त्वचा एक दिन में नहीं बदलती। रोज़ थोड़ा-थोड़ा करना ही काफ़ी है।",
  "महँगे प्रोडक्ट्स से ज़्यादा नियमितता काम आती है।",
  "आज का पानी, कल की चमक बनाता है।",
  "आपकी त्वचा सब सुनती है। उससे प्यार से पेश आइए।",
  "सनस्क्रीन सबसे अचऍछा एंटी-एजिंग कदम है इसे कभी न छोड़ें।",
  "छोटे कदम, बड़े नतीजे। बस शुरू कीजिए।",
  "आराम भी रूटीन का हिस्सा है। नींद भी स्किनकेयर है।",
  "कम ही बेहतर है। एक बार में एक ही नया प्रोडक्ट आज़माएँ।",
  "धैर्य रखिए। त्वचा में असली बदलाव में 4 से 6 हफ़्ते लगते हैं।",
  "चमक भीतर से आती है: पानी, नींद और ख़ुशी से।",
  "अपनी त्वचा की तुलना फ़िल्टर से न करें। असली त्वचा में बनावट होती है।",
  "आज अपने लिए 10 मिनट निकालिए। आप इसके हक़दार हैं।",
  "मज़बूत स्किन बैरियर, ख़ुश त्वचा।",
  "सुधार चाहिए, परफ़ेक्शन नहीं।",
  "एक दिन छूट गया? कोई बात नहीं, कल फिर शुरू करें।",
  "अपनी त्वचा को दोस्त की तरह रखिए, प्रोजेक्ट की तरह नहीं।",
  "त्वचा पर नरमी, मन पर नरमी।",
  "हाइड्रेटेड त्वचा ख़ुश त्वचा है। घूँट-घूँट पानी पिएँ।",
  "स्किनकेयर रोज़ की छोटी खुराक में ख़ुद का सम्मान है।",
  "आज जो करेंगे, वही तीन महीने बाद दिखेगा।",
  "ट्रेंड के पीछे न भागें। वही करें जो आपकी त्वचा को चाहिए।",
  "ज़्यादा मुस्कुराइए। यह सबसे सस्ता ग्लो-अप है।",
  "पिंपल्स अस्थायी होते हैं। नरमी रखें, उन्हें न नोचें।",
  "धीमा रूटीन, शांत मन, साफ़ त्वचा।",
  "आप जैसे हैं, वैसे ही ख़ूबसूरत हैं। स्किनकेयर बस देखभाल है।",
  "हल्के से धोएँ, अच्छे से मॉइस्चराइज़ करें, हमेशा सुरक्षा दें।",
  "आपकी भविष्य की त्वचा आज के लिए आपको धन्यवाद देगी।",
  "अभी एक गिलास पानी पिएँ। आपकी त्वचा शुक्रिया कहेगी।",
  "तनाव कम, चमक ज़्यादा।",
  "हर दिन एक नया पन्ना है। उसे चमकदार बनाइए।",
];

const List<String> _mr = [
  "त्वचा एका दिवसात बदलत नाही. रोज थोडं करणं पुरेसं आहे.",
  "महागड्या प्रॉडक्ट्सपेक्षा सातत्य जास्त उपयोगी ठरतं.",
  "आजचं पाणी, उद्याची चमक घडवतं.",
  "तुमची त्वचा सगळं ऐकते. तिच्याशी प्रेमाने वागा.",
  "सनस्क्रीन हे सर्वोत्तम अँटी-एजिंग पाऊल आहे. ते कधीही चुकवू नका.",
  "लहान पावलं, मोठे परिणाम. फक्त सुरुवात करा.",
  "विश्रांती हाही रूटीनचा भाग आहे. झोप हीसुद्धा स्किनकेअर आहे.",
  "कमी तेच जास्त. एका वेळी एकच नवीन प्रॉडक्ट वापरा.",
  "संयम ठेवा. त्वचेत खरा बदल व्हायला ४ ते ६ आठवडे लागतात.",
  "चमक आतून येते: पाणी, झोप आणि आनंदातून.",
  "तुमच्या त्वचेची फिल्टरशी तुलना करू नका. खऱ्या त्वचेला पोत असतो.",
  "आज स्वतःसाठी १० मिनिटं काढा. तुम्ही त्याला पात्र आहात.",
  "मजबूत स्किन बॅरियर, आनंदी त्वचा.",
  "प्रगती हवी, परिपूर्णता नाही.",
  "एक दिवस चुकला? काही हरकत नाही, उद्या पुन्हा सुरू करा.",
  "त्वचेला मित्रासारखं वागवा, प्रोजेक्टसारखं नाही.",
  "त्वचेवर मायेने, मनावरही मायेने.",
  "हायड्रेटेड त्वचा आनंदी त्वचा असते. थोडं थोडं पाणी पित राहा.",
  "स्किनकेअर म्हणजे रोजच्या छोट्या मात्रे स्वतःचा सन्मान.",
  "आज जे कराल, ते तीन महिन्यांनी दिसेल.",
  "ट्रेंडच्या मागे धावू नका. तुमच्या त्वचेला जे हवं ते करा.",
  "जास्त हसा. हा सर्वात स्वस्त ग्लो-अप आहे.",
  "पिंपल्स तात्पुरते असतात. हळुवार राहा, ते फोडू नका.",
  "सावकाश रूटीन, शांत मन, स्वच्छ त्वचा.",
  "तुम्ही जसे आहात तसेच सुंदर आहात. स्किनकेअर म्हणजे फक्त काळजी.",
  "हळुवार धुवा, नीट मॉइश्चराइझ करा, नेहमी संरक्षण द्या.",
  "तुमची भविष्यातली त्वचा आजसाठी तुमचे आभार मानेल.",
  "आत्ताच एक ग्लास पाणी प्या. तुमची त्वचा तुमचे आभार मानेल.",
  "ताण कमी, चमक जास्त.",
  "प्रत्येक दिवस नवं पान आहे. ता चमकदार बनवा.",
];
