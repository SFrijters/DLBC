/* http://www.d-programming-language.org/templates-revisited.html
   " Template Metaprogramming With Strings " */
template decimalDigit(const int n) {
  const string decimalDigit = "0123456789"[n..n+1];
}

template itoa(const long n) {
  static if (n < 0) {
    const string itoa = "-" ~ itoa!(-n);
  }
  else static if (n < 10) {
    const string itoa = decimalDigit!(n);
  }
  else {
    const string itoa = itoa!(n/10L) ~ decimalDigit!(n%10L);
  }
}

