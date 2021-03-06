      module m_q0p 
!> Q0P (offset Gamma points) generator
!! All of them are outputs when getq0p is called.
!! Read GWinput
!! Write Q0P: Q0P contains offset Gamma, or k points specified in GWinput
!!       EPSwklm: Sperical integration weitht. But currently only l=0 is used to keep positive definitness.
!!                 
      real(8),allocatable,protected:: q0i(:,:),wt(:)  ! Q0P and its weight.
      integer,protected:: nq0i,nq0itrue,nq0iadd            ! Number of Q0P
      integer,protected,allocatable:: ixyz(:)  ! ixyz(1:nq0i+nq0iadd) q0i for x,y,z directions
c      integer,protected:: nq0x
c      real(8),allocatable,protected:: q0x(:,:)
      contains

      subroutine getallq0p(iq0pin,newoffsetG,alat,plat,qlat,nnn,alp,alpv,
     & ngcxx,ngcx,nqbz,nqibz,nstbz,qbz,qibz,symops,ngrp,ngvect,lnq0iadd) !! All arguments are input.
      use m_keyvalue,only: getkeyvalue 
      implicit none
      integer,intent(in):: iq0pin
      logical,intent(in):: newoffsetG
      integer,intent(in):: nnn(3),nstbz(*),nqbz,nqibz,ngcxx,ngcx(nqbz),ngrp !n1q,n2q,n3q,
      real(8),intent(in):: alat,qlat(3,3),alp,alpv(3),plat(3,3)
     & ,qbz(3,nqbz),qibz(3,nqibz),symops(3,3,ngrp)
      integer,intent(in) ::ngvect(3,ngcxx,nqbz)

      integer::nq00ix,nx0,nq00i, xyz2lm(3)
      real(8):: xn !,www,wgtq0
      logical:: noq0p,timereversal
      real(8),allocatable:: q0x(:,:),wt0(:)
      real(8):: deltaq,deltaq_scale,delta8,delta5,emat(3,3)
      real(8):: pi=4d0*atan(1d0)
      real(8),allocatable:: wti(:),qi(:,:),epinv(:,:,:),cg(:,:,:),matxxl(:,:,:),
     &     dmlx(:,:),cy(:),yl(:),epinvq0i(:,:),wklm(:) !,norq0x(:) !,wqfac(:)
      integer:: bzcase=1,i,iq0i,ifidmlx,lmxax,lx,lxklm,j,iclose,llxxx
      real(8):: rrr(3),r2s,qxx(3),voltot,tripl
      integer,allocatable::irrx(:)

      real(8),allocatable:: funa(:,:),wsumau(:),yll(:,:),alpqg2,qg2,tpiba,wtrue00
      real(8):: qg(3), qdum(6)
      integer:: ig,lm,iq,ifile_handle
      integer:: nmm !not output

      integer:: ifi0,ifi00,il,ix,ni,ifinin
      integer:: nq0i0,nq0i00,nany,ifqpnt,ret

      integer,allocatable :: ndiv(:)
      real(8),allocatable:: qsave(:,:),   qmin(:,:),qmax(:,:)
      real(8),allocatable:: qany(:,:)
      logical:: anyq,ibzqq,lnq0iadd

      if(iq0pin==1) then
!! Normal mode. all inputs
         call getq0p(newoffsetG,alat,plat,qlat,nnn,alp,alpv, !apr2015
     i    ngcxx,ngcx,nqbz,nqibz,nstbz,qbz,qibz,symops,ngrp,ngvect,lnq0iadd)
         ifi0=ifile_handle()
         open (ifi0,file='Q0P')
         write(ifi0,"(3i5,' !nq0i iq0pin nq0iadd; weight q0p(1:3) ix')") nq0i,iq0pin,nq0iadd
         write(ifi0,"(d24.16,3x, 3d24.16,x,i1)" ) (wt(i),q0i(1:3,i),ixyz(i),i=1,nq0i+nq0iadd)
         close(ifi0)
!!
!! Get Q0P from GWinput
      elseif(iq0pin==2) then
         call getkeyvalue("GWinput","QforEPSIBZ",ibzqq,default=.false.)
         if(ibzqq) then
            write(6,*)'=== Find QforEPSIBZ=on === '
            nq0i= nqibz
            allocate( q0i(3,nq0i) )
            q0i = qibz
         else
            write(6,*)'==== Readin <QforEPS>or<QforEPS> in GWinput === '
            call getkeyvalue("GWinput","<QforEPS>", unit=ifinin,status=nq0i00,errstop='off')
            nq0i00 =max(nq0i00,0)
            if(nq0i00>0) close(ifinin)
            print *,' end of reaing QforEPS nq0i00',nq0i00,ifinin
            call getkeyvalue("GWinput","<QforEPSL>",unit=ifinin,status=nq0i0,errstop='off')
            nq0i0  =max(nq0i0,0)
            print *,' end of reaing QforEPSL nq0i0',nq0i0,ifinin
            if(nq0i0>0) then
               allocate( ndiv(nq0i0) )
               do i=1,nq0i0
                  read(ifinin,*) qdum(1:6), ndiv(i)
               enddo
               nq0i = nq0i00 + sum(ndiv)
               close(ifinin)
            else
               nq0i = nq0i00
            endif
            if(nq0i <=0) call rx( 'There are neither <QforEPS> nor <QforEPS>.')
            allocate( q0i(3,nq0i) )
            print *,' nq0i=',nq0i
            if(nq0i00>0) then
               call getkeyvalue("GWinput","<QforEPS>",unit=ifinin,status=nq0i00)
               do i=1,nq0i00
                  read (ifinin,*) q0i(1:3,i)
                  write (6,"('<QforEPS> ' 3f12.8)") q0i(:,i)
               enddo
               close(ifinin)    !25jan2006
            endif
            if(nq0i0>0) then
               call getkeyvalue("GWinput","<QforEPSL>",unit=ifinin,status=nq0i0)
               allocate( qmin(3,nq0i0), qmax(3,nq0i0) )
               do i=1, nq0i0
               read(ifinin,*)qmin(:,i), qmax(:,i), ndiv(i)
               write(6,"('<QforEPSL>',3f12.8,2x,3f12.8,i5)")qmin(:,i),qmax(:,i),ndiv(i)
               enddo
               close(ifinin)
               ni = nq0i00
               do il=1, nq0i0
                  do i=1, ndiv(il)
                     q0i(:,i+ni)= qmin(:,il)+ (qmax(:,il)-qmin(:,il))/ndiv(il) * i
                  enddo
                  ni= ni + ndiv(il)
               enddo
               deallocate(qmin,qmax,ndiv)
            endif
         endif
         allocate( wt(nq0i) )
         wt = 0d0
         ifi00=ifile_handle()
         open (ifi00,file='Q0P')
         write(ifi00,"(3i5,a)") nq0i,iq0pin,0, " !nq0i iq0pin ---"//
     &        "This is readin Q0P from GWinput <QforEPS> ---"
         write(ifi00,"(d24.16,3x, 3d24.16,i2)") (wt(i),q0i(1:3,i),0,i=1,nq0i)
         close(ifi00)
      endif

      print *,' end fo writing Q0P'
      call cputid (0)
!! Timereversal may require q0i. Anyway, qreduce0 will reduce the number of q points by symops.
      if(.not.timereversal().and.iq0pin==1) then
         write(6,*)" timereversal==off : add -Q0P points"
         do iq=1,nq0i
            q0i(:,iq+nq0i)= -q0i(:,iq)
         enddo
         nq0i=nq0i*2
      endif
!! === AnyQ mechanism. === q0i is extended. nq0i/=nq0itrue
      call getkeyvalue("GWinput","AnyQ",anyq,default=.false.)
      if(anyq.and.iq0pin==1) then
         print *,'AnyQ (read <QPNT> section =T'
!!     read q-points and states
         call getkeyvalue("GWinput","<QPNT>",unit=ifqpnt,status=ret)
         call readx   (ifqpnt,10)
         call readx   (ifqpnt,100)
         call readx   (ifqpnt,100)
         read (ifqpnt,*) nany
         print *,'  nany=',nany
         allocate(qany(3,nany))
         do ix=1,nany
            read (ifqpnt,*) i, qany(:,ix)
            write(6,'(i3,3f13.6)') ix,qany(:,ix)
         enddo
         nany =ix-1
         write(6,*)" Anyq mode: nany=",nany
         allocate(qsave(3,nq0i+nany))
         qsave(:,    1 :nq0i)     = q0i (:,1:nq0i)
         qsave(:,nq0i+1:nq0i+nany)= qany(:,1:nany)
         nq0itrue=nq0i !nov2015
         nq0i = nq0i+nany
         deallocate(q0i)
         allocate(q0i(3,nq0i))
         q0i=qsave
         deallocate(qsave)
         close(ifqpnt)
      else
         nq0itrue=nq0i !nov2015
      endif
      end subroutine getallq0p

!>- Q0P data set is given for 'getq0p'
!! only called 
      subroutine getq0p(newoffsetG,alat,plat,qlat,nnn,alp,alpv,
     & ngcxx,ngcx,nqbz,nqibz,nstbz,qbz,qibz,symops,ngrp,ngvect,lnq0iadd) !! All arguments are input.
!! this is called in subroutine mkqg2 
!!  output
!!    q0i (offset Gamma point)
!!    wt  (weight of q0i)
!!    EPSwklm (file)
!!
!! In addition, we write a file EPSwklm, which is key for new offset Gamma method.
!! deltaq_scale() given by Q0Pchoice in GWinput change the of offset Gamma method.
      use m_keyvalue,only: getkeyvalue 
      implicit none
      logical,intent(in):: newoffsetG,lnq0iadd
      integer,intent(in):: nnn(3),nstbz(*),nqbz,nqibz,ngcxx,ngcx(nqbz),ngrp 
      real(8),intent(in):: alat,qlat(3,3),alp,alpv(3),plat(3,3)
     & ,qbz(3,nqbz),qibz(3,nqibz),symops(3,3,ngrp)
      integer,intent(in) ::ngvect(3,ngcxx,nqbz)

      integer::nq00ix,nx0,nq00i, xyz2lm(3)!,nnnt
      real(8):: xn !,www,wgtq0
      logical:: noq0p,timereversal
      real(8),allocatable:: q0x(:,:),wt0(:)
      real(8):: deltaq,deltaq_scale,delta8,delta5,emat(3,3)
      real(8):: pi=4d0*atan(1d0)
      real(8),allocatable:: wti(:),qi(:,:),epinv(:,:,:),cg(:,:,:),matxxl(:,:,:),
     &     dmlx(:,:),cy(:),yl(:),epinvq0i(:,:),wklm(:) !,norq0x(:) !,wqfac(:)
      integer:: bzcase=1,i,iq0i,ifidmlx,lmxax,lx,lxklm,j,iclose,llxxx
      real(8):: rrr(3),r2s,qxx(3),voltot,tripl
      integer,allocatable::irrx(:)

      real(8),allocatable:: funa(:,:),wsumau(:),yll(:,:),alpqg2,qg2,tpiba,wtrue00
      real(8):: qg(3)
      integer:: ig,lm,iq,ifile_handle !,n1q,n2q,n3q
      integer:: nq0x,nmm ,iq0,iqx!not output
      real(8):: tolq=1d-8


      voltot = abs(alat**3*tripl(plat,plat(1,2),plat(1,3)))
c      n1q=nnn(1)
c      n2q=nnn(2)
c      n3q=nnn(3)
!! number of spherical points.
c  nq00ix=12 !spherical points
c  nq00ix=3   !spherical points
      nq00ix=6  
      nx0 = 1
      if(nx0==2) xn=3d0 ! ratio parameter for Q2 and Q1, 
! only effective for nx0=2 case
c      nq0x=nq00ix*nx0
      nq0x=nq00ix

c     nq0x=4*nx0
c     if(q0pchoice()/1000==1) then
c     nn1= (q0pchoice()-1000)/10
c     nn2= mod(q0pchoice()-1000,10)
c     nq0x= 4*nn1*nn2
c     print *,' mkqg: q0pchoice nq0x=',q0pchoice(),nq0x
c     endif
c$$$         if(newaniso) then    !feb2012
c$$$      nq0x=nq00ix
c$$$         elseif( q0pchoice()<0) then
c$$$c     nq0x = 8*abs (q0pchoice())
c$$$            nq0x = max( (2*abs(q0pchoice()))**3, 8*abs(q0pchoice()))
c$$$         endif
c      www = wgtq0p()

      call getkeyvalue("GWinput","TestNoQ0P",noq0p,default=.false.)
      if(noq0p) then
        nq00i=0
        print *,' TestNoQ0P=.true. '
        nq0i=0
      else
        nmm=1
        if(.not.timereversal()) nmm=2
        allocate( q0x(3,nq0x), wt0(nq0x), irrx(nq0x), wt(nq0x), q0i(3,nq0x*nmm)) 
        if(newoffsetG) then
          deltaq=deltaq_scale()*alat/(2*pi) !dq is 0.01 a.u.
          if(nq00ix==3) then
            nq00i=3
c     q0x(:,1)=(/-deltaq, deltaq,  deltaq/)
c     q0x(:,2)=(/deltaq, -deltaq,  deltaq/)
c     q0x(:,3)=(/deltaq, deltaq,  -deltaq/)
            do i=1,3
              q0x(:,i)= qlat(:,i)/nnn(i)/2d0*deltaq_scale()
            enddo
          elseif(nq00ix==6) then
!! six independent direction is required to calculate full dielectric matrix (symmetric -->six components).
            nq00i=6
            do i=1,3
            q0x(:,i)= qlat(:,i)/nnn(i)/2d0*deltaq_scale()
            enddo
c                  norq0x(1)=sqrt(sum(q0x(:,1)**2))
c                  norq0x(2)=sqrt(sum(q0x(:,2)**2))
c                  norq0x(3)=sqrt(sum(q0x(:,3)**2))
c before 21dec2012
c     q0x(:,4)= (q0x(:,1)-q0x(:,2))/2d0
c     q0x(:,5)= (q0x(:,2)-q0x(:,3))/2d0
c     q0x(:,6)= (q0x(:,3)-q0x(:,1))/2d0
c     norq0x(4)=sqrt(sum(q0x(:,4)**2))
c     norq0x(5)=sqrt(sum(q0x(:,5)**2))
c     norq0x(6)=sqrt(sum(q0x(:,6)**2))
c     q0x(:,4)= (q0x(:,1)-q0x(:,2))/norq0x(4)*(norq0x(1)+norq0x(2))/2d0
c     q0x(:,5)= (q0x(:,2)-q0x(:,3))/norq0x(5)*(norq0x(2)+norq0x(3))/2d0
c     q0x(:,6)= (q0x(:,3)-q0x(:,1))/norq0x(6)*(norq0x(3)+norq0x(1))/2d0
!! shorter ones. no normalization. dec2012
            if(sum((q0x(:,1)-q0x(:,2))**2)<sum((q0x(:,1)+q0x(:,2))**2)) then
              q0x(:,4)= (q0x(:,1)-q0x(:,2))/2d0
            else
              q0x(:,4)= (q0x(:,1)+q0x(:,2))/2d0
            endif
            if(sum((q0x(:,2)-q0x(:,3))**2)<sum((q0x(:,2)+q0x(:,3))**2)) then
              q0x(:,5)= (q0x(:,2)-q0x(:,3))/2d0
            else  
              q0x(:,5)= (q0x(:,2)+q0x(:,3))/2d0
            endif
            if(sum((q0x(:,3)-q0x(:,1))**2)<sum((q0x(:,3)+q0x(:,1))**2)) then
              q0x(:,6)= (q0x(:,3)-q0x(:,1))/2d0
            else  
              q0x(:,6)= (q0x(:,3)+q0x(:,1))/2d0
            endif
c     q0x(:,1)=(/-deltaq, deltaq,  deltaq/)
c     q0x(:,2)=(/deltaq, -deltaq,  deltaq/)
c     q0x(:,3)=(/deltaq, deltaq,  -deltaq/)
c     q0x(:,4)=(/deltaq, -deltaq,  -deltaq/)
c     q0x(:,5)=(/-deltaq, deltaq,  -deltaq/)
c     q0x(:,6)=(/-deltaq, -deltaq,  deltaq/)
c     nq00i=6
c     q0x(:,1)=(/deltaq, 0d0,    0d0/)
c     q0x(:,2)=(/0d0, deltaq,    0d0/)
c     q0x(:,3)=(/0d0,    0d0, deltaq/)
c     q0x(:,4)=(/0d0,   deltaq, deltaq/)
c     q0x(:,5)=(/deltaq, 0d0,   deltaq/)
c     q0x(:,6)=(/deltaq,deltaq, 0d0/)
          elseif(nq00ix==12) then
!! spherical design des.3.12.5
!! des.3.12.5
            nq00i=12
            delta8=0.850650808352d0*deltaq
            delta5=0.525731112119d0*deltaq
            q0x(:,1)=(/delta8, 0d0, -delta5/)
            q0x(:,2)=(/delta5, -delta8, 0d0/)
            q0x(:,3)=(/0d0,-delta5, delta8/)
            
            q0x(:,4)=(/delta8, 0d0, delta5/)
            q0x(:,5)=(/-delta5,-delta8,0d0/)
            q0x(:,6)=(/0d0,delta5,-delta8/)
            
            q0x(:,7)=(/-delta8,0d0,-delta5/)
            q0x(:,8)=(/-delta5,delta8,0d0/)
            q0x(:,9)=(/0d0,delta5,delta8/)
            
            q0x(:,10)=(/-delta8,0d0,delta5/)
            q0x(:,11)=(/delta5,delta8,0d0/)
            q0x(:,12)=(/0d0,-delta5,-delta8/)
          else
            call rx( 'mkqg: not implemented nq00i')
          endif
          do i=1,nq00i
            write(*,'(" initial q0x=",i3,3f9.3)')i,q0x(:,i)
          enddo
!! invariante dielectoric tensor.
          allocate(epinv(3,3,nq0x))
          call diele_invariant(q0x,nq0x,symops,ngrp,  epinv,q0i,nq0i, wt)
          print *,' nq0x,nmm nq0i=',nq0x,nmm,nq0i
!! == To convert invariant tensor on YL representation (Y00 and Y2m) ==
          lmxax=1
          allocate( cg((lmxax+1)**2,(lmxax+1)**2,(2*lmxax+1)**2) )
          allocate( matxxl(3,3,(2*lmxax+1)**2) )
          call rotcg(lmxax,(/1d0,0d0,0d0,0d0,1d0,0d0,0d0,0d0,1d0/),1,cg)
          xyz2lm( 2)=-1         !y
          xyz2lm( 3)= 0         !z
          xyz2lm( 1)= 1         !x
!! matxxl(i,j,L) = \int d\Omega x_i x_j  Y_L(\Omega), where x_i are nomlized.
          do i=1,3
            do j=1,3
              matxxl(i,j,:) = cg(xyz2lm(i)+3,xyz2lm(j)+3,:)*4d0*pi/3d0
!sqrt(4*pi/3) comes from normalization of Y_l=1.
            enddo
          enddo
!! epinv is expanded as
!!   <ehat| epinv|ehat> = \sum_lm dmlx(iq0i,lm) *Y_lm(ehat)
          allocate(dmlx(nq0i,9))
          do iq0i=1,nq0i
            do lx=1,9
              dmlx(iq0i,lx)=sum(epinv(:,:,iq0i)*matxxl(:,:,lx))
            enddo
          enddo
c$$$  !! check xxxxxxxxxxxxxxxxxxxx
c$$$  do lx=5,9
c$$$  do i=2,4
c$$$  do j=2,4
c$$$  write(*,"(' l1 l2 l= cg=',3i3,f9.5)")i-1,j-1,lx-7,cg(i,j,lx)
c$$$  enddo
c$$$  enddo
c$$$  write(*,*)
c$$$  enddo
c$$$  do lx=5,9
c$$$  do i=1,3
c$$$  do j=1,3
c$$$  write(*,"(' matxxl l1 l2 l= cg=',3i3,f9.5)")i,j,lx,matxxl(i,j,lx)
c$$$  enddo
c$$$  enddo
c$$$  write(*,*)
c$$$  enddo
c$$$  do lx=1,1
c$$$  do i=1,3
c$$$  do j=1,3
c$$$  write(*,"(' matxxl l1 l2 l= cg=',3i3,f9.5)")i,j,lx,matxxl(i,j,lx)
c$$$  enddo
c$$$  enddo
c$$$  write(*,*)
c$$$  enddo
c$$$  do iq0i=1,nq0i
c$$$  do lx=1,9
c$$$  write(*,"(' iq0i lx dmlx=',2i3,f9.3)")iq0i,lx,dmlx(iq0i,lx)
c$$$  enddo
c$$$  enddo

!! Test for one r vector as for <ehat|epinv|ehat> = \sum_lm dmlx(iq0i,lm) *Y_lm(ehat)
!! === generate YL for a test vector rrr (rrr is ehat above).====
          lx=2
          allocate(cy((lx+1)**2),yl((lx+1)**2))
          call sylmnc(cy,lx)
          rrr=(/.5d0,-.1d0,-0.7d0/) !test data
          rrr=rrr/sqrt(sum(rrr**2))
          call sylm(rrr,yl,lx,r2s) !spherical factor Y( q+G )
!! ===== check (rrr*emat*rrr = sum(dmlx* YL)
c     do lm=1,9; write(*,"('r lm=',3f8.3,i4,' ylm=',f8.3)") rrr,lm,cy(lm)*yl(lm) ;   enddo
          write(*,*)
          write(*,"(  ' test: r=',3f10.5)") rrr
!!
          do iq0i=1,nq0i
            write(*,"(' test: ylm   expansion=',i3,f10.5)") 
     &       iq0i,sum(dmlx(iq0i,:)*cy(:)*yl(:))
            emat=epinv(:,:,iq0i)
            write(*,"(' test: epinv expansion=',i3,f10.5)") 
     &       iq0i,sum(rrr*matmul(emat,rrr))
          enddo
          write(*,*)
          allocate( epinvq0i(nq0i,nq0i))
          do i=1,nq0i
          do j=1,nq0i         !epinvq0i= <q0i/|q0i|| epinv(:,:,iq0j)|q0i/|q0i|>
           epinvq0i(i,j)=sum(q0i(:,i)*matmul(epinv(:,:,j),q0i(:,i)))/sum(q0i(:,i)**2)
          enddo
          enddo
          deallocate(cy,yl)
          lxklm=6         !this is used for inversion procedure in hx0fp0.sc.m.f
c          nnnt=n1q*n2q*n3q
          allocate(wklm((lxklm+1)**2)) !wklm-->Klm in Comp.Phys. Comm 176(1007)1-13
          call getwklm(alat,voltot,plat,qlat,alp,qbz,nqbz,ngcx,ngcxx,ngvect, lxklm,nnn(1),nnn(2),nnn(3),
     o     wklm)                !,wqfac)
!! Takao think anisotropic treatment in Computer Phys. Comm 176(1007)1-13 
!! (in our version with auxially function) can be numerically prorematic.
!! We only keep wklm only up to l=2. (I observed high wklm(lm) components 
!! are largely negative --->it may cause numerical error).
!! 
!! From the begining, we can only excpect "virtual convergence on Nz" for 
!! NxNyNz for Si100 slab model in the paper.
!! (I still not understand why it does not show divergent behevior in the anisotropic case).
!!
c     print *,' set wklm=0 for l>2. But lxklm(for inversion of epsioln)=',lxklm
          do i=1,(lxklm+1)**2
            if(abs(wklm(i))>1d-6 ) write(6,'(" mkqg: l lm Wklm=",2i3,f9.4)')llxxx(i),i,wklm(i)
          enddo
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!     ! spherical design des.3.12.5 check. Because of angular momentum synsesize,
!     ! des.3.12.5 gives correct normalization of product up to l=2 (lm<=9)
c$$$  deallocate(cy,yl,q0x)
c$$$  nq00i=12
c$$$  allocate(cy((lxklm+1)**2),yll((lxklm+1)**2,nq00i))
c$$$  tpiba  = 2d0*pi/alat
c$$$  call sylmnc(cy,lxklm)
c$$$  allocate( q0x(3,nq00i) )
c$$$  delta8=0.850650808352d0 !*deltaq
c$$$  delta5=0.525731112119d0 !*deltaq
c$$$  q0x(:,1)=(/delta8, 0d0, -delta5/)
c$$$  q0x(:,2)=(/delta5, -delta8, 0d0/)
c$$$  q0x(:,3)=(/0d0,-delta5, delta8/)
c$$$  q0x(:,4)=(/delta8, 0d0, delta5/)
c$$$  q0x(:,5)=(/-delta5,-delta8,0d0/)
c$$$  q0x(:,6)=(/0d0,delta5,-delta8/)
c$$$  q0x(:,7)=(/-delta8,0d0,-delta5/)
c$$$  q0x(:,8)=(/-delta5,delta8,0d0/)
c$$$  q0x(:,9)=(/0d0,delta5,delta8/)
c$$$  q0x(:,10)=(/-delta8,0d0,delta5/)
c$$$  q0x(:,11)=(/delta5,delta8,0d0/)
c$$$  q0x(:,12)=(/0d0,-delta5,-delta8/)
c$$$  do iq=1,nq00i
c$$$  qg(1:3) = q0x(:,iq)
c$$$  call sylm(qg/sum(qg**2),yll(:,iq),lxklm,r2s) !spherical factor Y( q+G )
c$$$  c        print *,' qg for yll=',iq, qg
c$$$  c        print *,' yll=',cy(1:20)*yll(1:20,iq)
c$$$  enddo

!! normalization check
c     do lm1=1,(3+1)**2
c     do lm2=lm1,(3+1)**2
c     aaa=sum(cy(lm1)*cy(lm2)*yll(lm1,:)*yll(lm2,:))/12d0*4d0*pi
c     if(abs(aaa)>1d-6) write(6,"('ylm*ylm=',2i3,d13.5)")lm1,lm2,aaa
c     enddo
c     enddo
c     do lm1=1,(5+1)**2
c     aaa=sum(cy(lm1)*yll(lm1,:))
c     if(abs(aaa)>1d-6) write(6,"('ylm*ylm=',i3,d13.5)")lm1,aaa
c     enddo
c     stop ' xxxxxxxxx spherical normalization xxxxxxxx'
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

c$$$!! test wklm
c$$$          if(allocated(cy)) deallocate(cy,yl)
c$$$          allocate(cy((lxklm+1)**2),yl((lxklm+1)**2),funa((lxklm+1)**2,nqbz))
c$$$          tpiba  = 2d0*pi/alat
c$$$          call sylmnc(cy,lxklm)
c$$$          do iq=1,nqbz
c$$$            funa(:,iq)=0d0
c$$$            do ig=1,ngcx(iq)
c$$$              qg(1:3) = tpiba * (qbz(1:3,iq)+ matmul(qlat, ngvect(1:3,ig,iq)))
c$$$              qg2     = sum(qg(1:3)**2)
c$$$              alpqg2= alp* qg2
c$$$              call sylm(qg/sqrt(qg2),yl,lxklm,r2s) !spherical factor Y( q+G )
c$$$              if(qg2<1d-6) cycle !for iq=1 remove divergent part
c$$$              funa(:,iq) = funa(:,iq) + exp(-alpqg2)/qg2*cy(:)*yl(:) !cy*yl =Y_L(qg/|qg|) 
c$$$            enddo
c$$$          enddo
c$$$          allocate(wsumau((lxklm+1)**2))
c$$$          do lm=1,(lxklm+1)**2
c$$$            wsumau(lm) = sum(funa(lm,2:nqbz))/dble(nqbz)
c$$$c            if(abs(funa(lm,1))>1d-8) write(6,*)' funa1=',lm,funa(lm,1)
c$$$c        write(6,"('  wsum fnua=',i3,8f10.5)") lm,wsumau(lm)
c$$$            if(lm==1) then
c$$$c              write(*,"('lm l wklm wtrue wsum wsummesh',2i3,4f12.8)")
c$$$c     &         lm,llxxx(lm),wklm(lm), wtrue00,wklm(lm)+wsumau(lm), wsumau(lm) !,wklm(lm)+wsumau(lm)-wtrue00
c$$$            else
c$$$              write(*,"('lm l wsumau+wklm+w0const = wtotal ',2i3,15f12.8)")
c$$$     &         lm,llxxx(lm), wklm(lm), wsumau(lm), funa(lm,1)/dble(nqbz), wklm(lm)+wsumau(lm)+funa(lm,1)/dble(nqbz)
c$$$            endif
c$$$          enddo
c$$$          stop 'xxxxxxxxxxxxxxxxxxxxxxxx'

          ifidmlx = ifile_handle()
          open(ifidmlx,file='EPSwklm',form='unformatted')
          write(ifidmlx) nq0i,lxklm
          write(ifidmlx) dmlx, epinv(:,:,1:nq0i),epinvq0i
          write(ifidmlx) wklm
          close(ifidmlx)
        else
          call setq0_2(bzcase, alat, voltot,plat, qlat,alpv, qbz, nstbz, nqbz,
     i     ngcx, ngcxx, ngvect,   nq0x,nx0,xn,nnn(1),nnn(2),nnn(3), !n1q,n2q,n3q,
     o     q0x,wt0,nq00i)
!     ! ... inequivalent q0x points ...
          nq0i=0
          call q0irre(qibz,0,q0x,wt0,nq00i,symops,ngrp,   q0i,nq0i,wt,plat,.false.,0,irrx)
        endif
        deallocate(irrx)
      endif
      write(6,"('i wt q0i=',i3,f16.7,2x,3d23.15)")(i,wt(i),q0i(1:3,i),i=1,nq0i)

!! Add q0
      nq0iadd=0
      allocate(ixyz(nq0i+3)) !nq0i+3 is large enough
      ixyz=0
      if(lnq0iadd) then
        if(nq00ix/=6 ) then
          call rx('mkqg: we assumes q0x(:,i)= qlat(:,i)/nnn(i)/2d0*deltaq_scale() for 1=1,3' )
        endif  
        do iq=1,3           !we assume q0x(:,i)= qlat(:,i)/nnn(i)/2d0*deltaq_scale() for i=1,3
          do iq0=1,nq0i
            if(sum(abs(q0x(:,iq)-q0i(:,iq0)))<tolq) then
              ixyz(iq0)=iq
              goto 1011
            endif  
          enddo
          nq0iadd = nq0iadd+1
          ixyz( nq0i+nq0iadd)= iq
          q0i(:,nq0i+nq0iadd)=q0x(:,iq)
 1011     continue
        enddo
!! check write
c        do iq=1,nq0i+nq0iadd
c          write(6,"(' Q0P iq q ixyz ',i5,3f10.4,i3)") iq,q0i(:,iq),ixyz(iq)
c        enddo
      endif
      end subroutine getq0p
      end module m_q0p
