{check = match($0, /###(.*)###/)}
{if(check) {
    tmp[0] = substr($NF, 21, RLENGTH)
    tmp[1] = substr($NF, 24, RLENGTH-6)
    }}
{
    if(tmp[1]) {
        join_mark = ""
        cont = ""
        while(getline l < tmp[1]) {
            cont = cont join_mark l
            join_mark = "\n"
        }
        gsub(tmp[0], cont)
        gsub(tmp[0], "\\&amp;") # required to escape the ampersand.
        gsub("<job parameters>", "\\&lt;job parameters\\&gt;")
    }
    gsub("utf-8", "IBM-1047")
}
{print}