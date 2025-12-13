import 'package:flutter/material.dart';
import 'package:gpt_box/main.dart';
import 'package:language_picker/languages.dart';
import 'package:language_picker/language_picker.dart';

Language selectedDialogLanguage = Languages.defaultLanguages.firstWhere(
  (lang) => lang.name == translatorConfig.outputLang,
  orElse: () => Languages.defaultLanguages.first, // fallback if no match
);

// It's sample code of Dialog Item.
Widget _buildDialogItem(Language language) => Row(
  children: <Widget>[
    Text(language.name),
    SizedBox(width: 8.0),
    Flexible(child: Text("(${language.isoCode})")),
  ],
);

void openLanguagePickerDialog(BuildContext context) => showDialog(
  context: context,
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(primaryColor: Colors.pink),
    child: LanguagePickerDialog(
      titlePadding: EdgeInsets.all(8.0),
      searchCursorColor: Colors.pinkAccent,
      searchInputDecoration: InputDecoration(hintText: 'Search...'),
      isSearchable: true,
      title: Text('Select your language'),
      onValuePicked: (Language language) {
        translatorConfig.outputLang = language.name;
        translatorConfig.save();

        print(selectedDialogLanguage.name);
        print(selectedDialogLanguage.isoCode);
      },
      itemBuilder: _buildDialogItem,
    ),
  ),
);
