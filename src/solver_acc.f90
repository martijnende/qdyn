! functions for solver

module solver_acc

  implicit none

  private 

  public :: check_stop, do_bsstep

contains


!=====================================================================
! stop_check: 
!
subroutine check_stop(pb)

  use problem_class
  use output, only : time_write
  type(problem_type), intent(inout) :: pb
  double precision :: vmax_old = 0d0, vmax_older = 0d0
  save vmax_old, vmax_older

  if (pb%itstop == 0) then
      !         STOP soon after end of slip localization 
    if (pb%NSTOP == 1) then
      if (pb%ot%llocnew > pb%ot%llocold) pb%itstop=pb%it+2*pb%ot%ntout

      ! STOP soon after maximum slip rate
    elseif (pb%NSTOP == 2) then

      if (pb%it > 2 .and. vmax_old > vmax_older .and. pb%v(pb%ot%ivmax) < vmax_old)  &
          pb%itstop = pb%it+10*pb%ot%ntout
      vmax_older = vmax_old
      vmax_old = pb%v(pb%ot%ivmax)

        !         STOP at a slip rate threshold
    elseif (pb%NSTOP == 3) then    
      if (pb%v(pb%ot%ivmax) > pb%tmax) pb%itstop = pb%it    !here tmax is threshhold velocity

        !         STOP if time > tmax
    else
      call time_write(pb)
      if (pb%tmax > 0.d0 .and. pb%time > pb%tmax) pb%itstop = pb%it
    endif
  endif
    
end subroutine check_stop




!=====================================================================
! do bs_step, pack and unpack 
!
subroutine do_bsstep(pb)

  use problem_class
  type(problem_type), intent(inout) :: pb

  double precision, dimension(:), allocatable ::  yt, dydt, yt_scale
  
  allocate (yt(pb%neqs*pb%mesh%nn))
  allocate (dydt(pb%neqs*pb%mesh%nn))
  allocate (yt_scale(pb%neqs*pb%mesh%nn))

  !-------Pack v, theta into yt---------------------------------    
  yt(1::pb%neqs) = pb%v
  yt(2::pb%neqs) = pb%theta
  dydt(1::pb%neqs) = pb%dv_dt
  dydt(2::pb%neqs) = pb%dtheta_dt
  !-------Pack v, theta into yt--------------------------------- 
  ! One step 
  !--------Call EXT routine bsstep [Bulirsch-Stoer Method] --------------
  !-------- 
  yt_scale=dabs(yt)+dabs(pb%dt_try*dydt)
  call bsstep(yt,dydt,pb%neqs*pb%mesh%nn,pb%time,pb%acc,yt_scale,pb)
  if (pb%dt_max >  0.d0) then
    pb%dt_try = min(pb%dt_next,pb%dt_max)
  else
    pb%dt_try = pb%dt_next
  endif
  !-------Unpack yt into v, theta--------------------------------- 
  pb%v = yt(1::pb%neqs)
  pb%theta = yt(2::pb%neqs)
  pb%dv_dt = dydt(1::pb%neqs)
  pb%dtheta_dt = dydt(2::pb%neqs) 
  !-------Unpack yt into v, theta--------------------------------- 

  deallocate(yt,dydt,yt_scale)

end subroutine do_bsstep



!=====================================================================
! Update field: slip, tau, potency potency rate, crack,    
!
subroutine update_field(pb)
  
  use output, only : crack_size
  use problem_class
  type(problem_type), intent(inout) :: pb
  integer :: i  
  double precision :: vtemp 
  ! Update slip, stress. 
  pb%slip = pb%slip + pb%v*pb%dt_did
  pb%tau = (pb%mu_star-pb%a*log(pb%v1/pb%v+1d0)+pb%b*log(pb%theta/pb%theta_star)+1d0)    &
    * pb%sigma   
  ! update potency and potency rate
  pb%pot = sum(pb%slip) * pb%mesh%dx
  pb%pot_rate = sum(pb%v) * pb%mesh%dx
  ! update crack size
  pb%ot%lcold = pb%ot%lcnew
  pb%ot%lcnew = crack_size(pb%slip,pb%mesh%nn)
  pb%ot%llocold = pb%ot%llocnew
  pb%ot%llocnew = crack_size(pb%dtau_dt,pb%mesh%nn)
  ! Output time series at max(v) location
  
  vtemp=0d0
  do i=1,pb%mesh%nn
     if ( pb%v(i) > vtemp) then
       vtemp = pb%v(i)
       pb%ot%ivmax = i
     end if
  end do

end subroutine update_field



end module solver_acc
