// Written in the D programming language.

/**
   Helper functions and templates for CTFE. Based on 
   $(LINK http://www.d-programming-language.org/templates-revisited.html)
   " Template Metaprogramming With Strings "

Copyright: Stefan Frijters 2011-2014

License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.mixinhelper;

/**
   Converts a digit to a string at compile time.

   Param:
     n = integer digit
*/
template decimalDigit(const int n) {
  const string decimalDigit = "0123456789"[n..n+1];
}

/**
   Converts an integer to a string at compile time.

   Param:
     n = integer to convert
*/
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

