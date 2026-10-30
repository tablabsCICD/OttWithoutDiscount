import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ott/app/core/utils/text_capitalization_formatter.dart';
import 'package:wc_form_validators/wc_form_validators.dart';

export 'package:ott/app/core/utils/text_capitalization_formatter.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType textInputType;
  final int maxLine;
  final bool isPhoneNumber;
  final bool isValidator;
  final bool isEmail;
  final bool isName;
  final bool isDigits;
  final TextCapitalization capitalization;
  final IconData? iconData;
  final bool isPassword;
  final bool? readOnly;
  final String? validatorMsg;
  final String? label;
  final Function? onTap;
  final Function(String)? onValueChange;
  final IconData? suffixIcon;
  final Widget? prefixIcon;
  final Color? backgroundColor;
  final String? Function(String?)? validator;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const CustomTextField({
    required this.controller,
    required this.hintText,
    required this.textInputType,
    this.maxLine = 1,
    this.validatorMsg,
    this.isPhoneNumber = false,
    this.isValidator = true,
    this.isEmail = false,
    this.isName = false,
    this.isDigits = false,
    this.capitalization = TextCapitalization.none,
    this.iconData,
    this.isPassword = false,
    this.readOnly,
    this.onTap,
    this.label,
    this.onValueChange,
    this.suffixIcon,
    this.prefixIcon,
    this.backgroundColor,
    this.validator,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    super.key,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    var selectedTheme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null)
            Text(
              widget.label!,
              style: TextStyle(
                color: selectedTheme.canvasColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 5),
          TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            obscureText: widget.isPassword ? _isObscure : false,
            keyboardType: widget.textInputType,
            textInputAction: widget.textInputAction,
            textCapitalization: _effectiveCapitalization,
            readOnly: widget.readOnly ?? false,
            onTap: widget.onTap == null ? null : () => widget.onTap!(),
            onFieldSubmitted: widget.onFieldSubmitted,
            maxLines: widget.maxLine,
            cursorColor: const Color(0xFFE50914),
            inputFormatters: _buildInputFormatters(),
            validator: _buildValidator(),
            style: TextStyle(color: selectedTheme.canvasColor, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: widget.backgroundColor ?? selectedTheme.cardColor,
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: selectedTheme.canvasColor,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: selectedTheme.primaryColor),
                borderRadius: BorderRadius.circular(6),
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                        color: selectedTheme.canvasColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    )
                  : (widget.suffixIcon != null
                      ? Icon(
                          widget.suffixIcon,
                          color: selectedTheme.canvasColor,
                        )
                      : null),
              prefixIcon: widget.prefixIcon,
            ),
          ),
        ],
      ),
    );
  }

  String? Function(String?)? _buildValidator() {
    if (widget.validator != null) return widget.validator;
    if (!widget.isValidator) return null;
    if (widget.isPhoneNumber) {
      return Validators.compose([
        Validators.required('Phone number is required'),
        Validators.minLength(10, 'Mobile number cannot be less than 10 digits'),
        Validators.maxLength(
            10, 'Mobile number cannot be greater than 10 digits'),
      ]);
    } else if (widget.isEmail) {
      return Validators.compose([
        Validators.required('Email is required'),
        Validators.email('Invalid email address'),
      ]);
    } else if (widget.isName) {
      return Validators.compose([
        Validators.patternString(r"^[A-Za-z]+$", 'Only alphabets are allowed'),
        Validators.required('${widget.hintText} is required'),
      ]);
    } else if (widget.isDigits) {
      return Validators.compose([
        Validators.patternRegExp(
            RegExp(r"^[0-9]*$"), 'Only digits are allowed'),
        Validators.required('${widget.hintText} is required'),
      ]);
    } else {
      return Validators.required('This field is required');
    }
  }

  List<TextInputFormatter> _buildInputFormatters() {
    if (widget.isPhoneNumber) {
      return [FilteringTextInputFormatter.digitsOnly];
    }

    return [
      if (widget.maxLine == 1) FilteringTextInputFormatter.singleLineFormatter,
      if (_effectiveCapitalization == TextCapitalization.words)
        CapitalizeWordsTextInputFormatter(),
      if (_effectiveCapitalization == TextCapitalization.sentences)
        CapitalizeSentencesTextInputFormatter(),
    ];
  }

  TextCapitalization get _effectiveCapitalization {
    if (widget.capitalization != TextCapitalization.none) {
      return widget.capitalization;
    }
    if (widget.isPassword ||
        widget.isEmail ||
        widget.isPhoneNumber ||
        widget.isDigits ||
        widget.textInputType == TextInputType.emailAddress ||
        widget.textInputType == TextInputType.phone ||
        widget.textInputType == TextInputType.number ||
        widget.textInputType == TextInputType.url) {
      return TextCapitalization.none;
    }
    if (widget.isName || widget.textInputType == TextInputType.name) {
      return TextCapitalization.words;
    }
    if (widget.maxLine > 1 || widget.textInputType == TextInputType.multiline) {
      return TextCapitalization.sentences;
    }
    return TextCapitalization.none;
  }
}
