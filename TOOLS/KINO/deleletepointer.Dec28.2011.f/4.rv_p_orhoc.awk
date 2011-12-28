BEGIN {
 str=strftime("%b.%d.%Y")
 comment="ckino " str ": "

}
/^ .*rv_p_orhoc/{
  po="rv_p_orhoc"
  al="rv_a_orhoc"
  print comment,$0

  gsub(po,al)
  if (match($0,"nullify")) {next}

  sub("associated","allocated")
  if (match($0,"[ )]allocate\\(") ) {
    s=$0
    sub("^.*allocate\\(","",s)
    sub(al ".*$","",s)
    s= s al

    spc=$0
    sub("allocate.*$","",spc)
    print spc "if (allocated(" s ")) deallocate(" s ")"
  }
  
  if (match($0,"real\\(8\\) *, *pointer")) {
    sub("pointer","allocatable")
    sub("=>NULL\\(\\)","")
  }
}
{print }
