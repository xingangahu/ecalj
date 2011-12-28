
BEGIN{
 str=strftime("%b.%d.%Y")
 comment="ckino " str ": "
}

/^ .*rv_p_ocy/{

 st="slat%"
 po="rv_p_ocy"
 al="rv_a_ocy"
 ty="real(8)"

 print comment,$0
 ty_sub=ty
 sub("\\(","\\(",ty_sub)
 sub("\\)","\\)",ty_sub)
 gsub(ty_sub " *, *pointer *::",ty " , allocatable ::")
 gsub("=>NULL\\(\\)","")
 gsub(po,al)
 if (match($0,"nullify")) { 
  print "        if (allocated(" st al ")) deallocate(" st al ")"
  next; 
 }
 if (match($0,"allocate\\(" st po)) {
  print "        if (allocated("st al")) deallocate(" st al ")"
 }

 gsub("associated\\(","allocated(")
}
{print}