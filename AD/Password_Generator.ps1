## Simple password generator. Combines 3 words from an array, the last digit of the current year, and '!'

$word_list = @('Drown','Class','Ghost','Evoke','Exile','Split','Brush','Alarm','Clear','Tower','Handy','Guide','Strap','Grant','Server','Fight','Amber','Table')

$password = ($word_list | Get-Random -Count 3) -join ''

$last_digit_year = (Get-Date).Year.ToString()[-1]

$password += $last_digit_year += '!'

write-output $password