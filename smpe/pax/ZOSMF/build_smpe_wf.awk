{match($0, /###(.*)###/, tmp)}
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