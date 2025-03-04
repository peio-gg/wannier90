!-*- mode: F90 -*-!
!------------------------------------------------------------!
! This file is distributed as part of the Wannier90 code and !
! under the terms of the GNU General Public License. See the !
! file `LICENSE' in the root directory of the Wannier90      !
! distribution, or http://www.gnu.org/copyleft/gpl.txt       !
!                                                            !
! The webpage of the Wannier90 code is www.wannier.org       !
!                                                            !
! The Wannier90 code is hosted on GitHub:                    !
!                                                            !
! https://github.com/wannier-developers/wannier90            !
!------------------------------------------------------------!
!                                                            !
!  w90_io: file io and timing functions                      !
!                                                            !
!------------------------------------------------------------!

module w90_io

  !! Module to handle operations related to file input and output.

  use w90_constants, only: dp

  implicit none

  private

  logical, public, save :: post_proc_flag                        !! Are we in post processing mode
  character(len=10), parameter, public :: w90_version = '3.1.0 ' !! Label for this version of wannier90

  public :: io_stopwatch_start
  public :: io_stopwatch_stop
  public :: io_commandline
  public :: io_date
  public :: io_file_unit
  public :: io_get_seedname
  public :: io_print_timings
  public :: io_time
  public :: io_wallclocktime

contains

  ! was io_stopwatch(tag, 1, error), acts on stopwatch 1
  !=====================================
  subroutine io_stopwatch_start(tag, timers)
    !=====================================
    !! Stopwatch to time parts of the code
    !=====================================

    use w90_types, only: timer_list_type, nmax

    implicit none

    ! arguments
    type(timer_list_type), intent(inout) :: timers

    character(len=*), intent(in) :: tag
    !! Which stopwatch to act upon
    !integer, intent(in)  :: mode
    !! Action  1=start 2=stop

    ! local variables
    integer :: i
    real(kind=dp) :: t

    call cpu_time(t)

    do i = 1, timers%nnames
      if (timers%clocks(i)%label .eq. tag) then
        timers%clocks(i)%ptime = t
        timers%clocks(i)%ncalls = timers%clocks(i)%ncalls + 1
        return
      endif
    enddo

    if (.not. timers%overflow) then
      if (timers%nnames == nmax) then
        timers%overflow = .true.
      else
        timers%nnames = timers%nnames + 1

        timers%clocks(timers%nnames)%label = tag
        timers%clocks(timers%nnames)%ctime = 0.0_dp
        timers%clocks(timers%nnames)%ptime = t
        timers%clocks(timers%nnames)%ncalls = 1
      endif
    endif

    return

  end subroutine io_stopwatch_start

  ! was io_stopwatch(tag, 2, error), acts on stopwatch 2
  !=====================================
  subroutine io_stopwatch_stop(tag, timers)
    !=====================================
    !! Stopwatch to time parts of the code
    !=====================================
    use w90_types, only: timer_list_type

    implicit none

    ! arguments
    character(len=*), intent(in) :: tag
    type(timer_list_type), intent(inout) :: timers
    !! Which stopwatch to act upon
    !integer, intent(in)  :: mode
    !! Action  1=start 2=stop

    ! local variables
    integer :: i
    real(kind=dp) :: t

    call cpu_time(t)

    do i = 1, timers%nnames
      if (timers%clocks(i)%label .eq. tag) then
        timers%clocks(i)%ctime = timers%clocks(i)%ctime + t - timers%clocks(i)%ptime
        return
      endif
    end do

    return

  end subroutine io_stopwatch_stop

  !================================================
  subroutine io_print_timings(timers, stdout)
    !================================================
    !
    !! Output timing information to stdout
    !
    !================================================
    use w90_types, only: timer_list_type

    implicit none

    type(timer_list_type), intent(in) :: timers
    integer, intent(in) :: stdout
    integer :: i

    if (timers%overflow) then
      write (stdout, '(1x,a)') 'Warning: Timer array overflowed, some timing data has been lost'
    endif
    write (stdout, '(/1x,a)') '*===========================================================================*'
    write (stdout, '(1x,a)') '|                             TIMING INFORMATION                            |'
    write (stdout, '(1x,a)') '*===========================================================================*'
    write (stdout, '(1x,a)') '|    Tag                                                Ncalls      Time (s)|'
    write (stdout, '(1x,a)') '|---------------------------------------------------------------------------|'
    do i = 1, timers%nnames
      write (stdout, '(1x,"|",a50,":",i10,4x,f10.3,"|")') &
        timers%clocks(i)%label, timers%clocks(i)%ncalls, timers%clocks(i)%ctime
    enddo
    write (stdout, '(1x,a)') '*---------------------------------------------------------------------------*'

    return

  end subroutine io_print_timings

  !================================================
  subroutine io_get_seedname(seedname)
    !================================================
    !
    !! Get the seedname from the commandline
    !
    !================================================

    implicit none

    integer :: num_arg
    character(len=50) :: ctemp
    character(len=50), intent(inout)  :: seedname

    post_proc_flag = .false.

    num_arg = command_argument_count()
    if (num_arg == 0) then
      seedname = 'wannier'
    elseif (num_arg == 1) then
      call get_command_argument(1, seedname)
      if (index(seedname, '-pp') > 0) then
        post_proc_flag = .true.
        seedname = 'wannier'
      end if
    else
      call get_command_argument(1, seedname)
      if (index(seedname, '-pp') > 0) then
        post_proc_flag = .true.
        call get_command_argument(2, seedname)
      else
        call get_command_argument(2, ctemp)
        if (index(ctemp, '-pp') > 0) post_proc_flag = .true.
      end if

    end if

    ! If on the command line the whole seedname.win was passed, I strip the last ".win"
    if (len(trim(seedname)) .ge. 5) then
      if (seedname(len(trim(seedname)) - 4 + 1:) .eq. ".win") then
        seedname = seedname(:len(trim(seedname)) - 4)
      end if
    end if

  end subroutine io_get_seedname

  !================================================
  subroutine io_commandline(prog, dryrun, seedname)
    !================================================
    !
    !! Parse the commandline
    !
    !================================================

    implicit none

    character(len=50), intent(in) :: prog
    !! Name of the calling program
    logical, intent(out) :: dryrun
    !! Have we been asked for a dryrun
    character(len=50), intent(inout)  :: seedname

    integer :: num_arg, loop
    character(len=50), allocatable :: ctemp(:)
    logical :: print_help, print_version
    character(len=10) :: help_flag(3), version_flag(3), dryrun_flag(3)

    help_flag(1) = '-h    '
    help_flag(2) = '-help '
    help_flag(3) = '--help '

    version_flag(1) = '-v    '
    version_flag(2) = '-version '
    version_flag(3) = '--version '

    dryrun_flag(1) = '-d    '
    dryrun_flag(2) = '-dryrun '
    dryrun_flag(3) = '--dryrun '

    post_proc_flag = .false.
    print_help = .false.
    print_version = .false.
    dryrun = .false.

    num_arg = command_argument_count()
    allocate (ctemp(num_arg))
    do loop = 1, num_arg
      call get_command_argument(loop, ctemp(loop))
    end do

    if (num_arg == 0) then
      ! program called without any argument
      print_help = .true.
    elseif (num_arg == 1) then
      ! program called with one argument
      if (any(index(ctemp(1), help_flag(:)) > 0)) then
        print_help = .true.
      elseif (any(index(ctemp(1), version_flag(:)) > 0)) then
        print_version = .true.
      elseif ((ctemp(1) (1:1) == '-')) then
        !catch any other flag. Note seedname can't start with '-'
        print_help = .true.
      else  ! must be the seedname
        seedname = trim(ctemp(1))
      endif
    else ! not 2 - as mpi call might add commands to argument list
      if (any(index(ctemp(1), help_flag(:)) > 0)) then
        print_help = .true.
      elseif (any(index(ctemp(1), version_flag(:)) > 0)) then
        print_version = .true.
      elseif (any(index(ctemp(1), dryrun_flag(:)) > 0)) then
        dryrun = .true.
        seedname = trim(ctemp(2))
        if (seedname(1:1) == '-') print_help = .true.
      elseif (index(ctemp(1), '-pp') > 0) then
        post_proc_flag = .true.
        seedname = trim(ctemp(2))
        if (seedname(1:1) == '-') print_help = .true.
      else  ! must be the seedname
        seedname = trim(ctemp(1))
        if (seedname(1:1) == '-') print_help = .true.
      endif
    endif

    ! If on the command line the whole seedname.win was passed, I strip the last ".win"
    if (len(trim(seedname)) .ge. 5) then
      if (seedname(len(trim(seedname)) - 4 + 1:) .eq. ".win") then
        seedname = seedname(:len(trim(seedname)) - 4)
      end if
    end if

    if (print_help) then
      if (prog == 'wannier90') then
        write (6, '(a)') 'Wannier90: The Maximally Localised Wannier Function Code'
        write (6, '(a)') 'http://www.wannier.org'
        write (6, '(a)') ' Usage:'
        write (6, '(a)') '  wannier90.x <seedname>               : Runs file <seedname>.win'
        write (6, '(a)') '  wannier90.x -pp <seedname>           : Write postprocessing files for <seedname>.win'
        write (6, '(a)') '  wannier90.x [-d|--dryrun] <seedname> : Perform a dryrun calculation on files <seedname>.win'
        write (6, '(a)') '  wannier90.x [-v|--version]           : print version information'
        write (6, '(a)') '  wannier90.x [-h|--help]              : print this help message'
      elseif (prog == 'postw90') then
        write (6, '(a)') 'postw90: Post-processing for the Wannier90 code'
        write (6, '(a)') 'http://www.wannier.org'
        write (6, '(a)') ' Usage:'
        write (6, '(a)') '  First run wannier90.x then'
        write (6, '(a)') '  postw90.x <seedname>               : Runs file <seedname>.win'
        write (6, '(a)') '  postw90.x [-d|--dryrun] <seedname> : Perform a dryrun calculation on files <seedname>.win'
        write (6, '(a)') '  postw90.x [-v|--version]           : print version information'
        write (6, '(a)') '  postw90.x [-h|--help]              : print this help message'
      end if
      stop
    endif

    if (print_version) then
      if (prog == 'wannier90') then
        write (6, '(a,a)') 'Wannier90: ', trim(w90_version)
      elseif (prog == 'postw90') then
        write (6, '(a,a)') 'Postw90: ', trim(w90_version)
      endif
      stop
    end if

  end subroutine io_commandline

!  !================================================
!  subroutine io_error(error_msg, stdout, seedname)
!    !================================================
!    !
!    !! Abort the code giving an error message
!    !
!    !================================================
!
!    implicit none
!
!    character(len=*), intent(in) :: error_msg
!    character(len=50), intent(in)  :: seedname
!    integer :: stdout
!
!    ! calls mpi_abort on mpi_comm_world iff compiled with MPI support
!    call comms_abort(seedname, error_msg, stdout)
!    close (stdout)
!
!    write (*, '(1x,a)') trim(error_msg)
!    write (*, '(A)') "Error: examine the output/error file for details"
!
!#ifdef EXIT_FLAG
!    call exit(1)
!#else
!    STOP
!#endif
!
!  end subroutine io_error

  !================================================
  subroutine io_date(cdate, ctime)
    !================================================
    !
    !! Returns two strings containing the date and the time
    !! in human-readable format. Uses a standard f90 call.
    !
    !================================================
    implicit none
    character(len=9), intent(out) :: cdate
    !! The date
    character(len=9), intent(out) :: ctime
    !! The time

    character(len=3), dimension(12) :: months
    data months/'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', &
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'/
    integer date_time(8)
    !
    call date_and_time(values=date_time)
    !
    write (cdate, '(i2,a3,i4)') date_time(3), months(date_time(2)), date_time(1)
    write (ctime, '(i2.2,":",i2.2,":",i2.2)') date_time(5), date_time(6), date_time(7)

  end subroutine io_date

  !================================================
  function io_time()
    !================================================
    !
    !! Returns elapsed CPU time in seconds since its first call.
    !! Uses standard f90 call
    !
    !================================================
    use w90_constants, only: dp
    implicit none

    real(kind=dp) :: io_time

    ! t0 contains the time of the first call
    ! t1 contains the present time
    real(kind=dp) :: t0, t1
    logical :: first = .true.
    save first, t0
    !
    call cpu_time(t1)
    !
    if (first) then
      t0 = t1
      io_time = 0.0_dp
      first = .false.
    else
      io_time = t1 - t0
    endif
    return
  end function io_time

  !================================================!
  function io_wallclocktime()
    !================================================!
    ! Returns elapsed wall clock time in seconds since its first call  !
    !
    !================================================

    use w90_constants, only: dp, i64

    implicit none

    real(kind=dp) :: io_wallclocktime

    integer(kind=i64) :: c0, c1
    integer(kind=i64) :: rate
    logical :: first = .true.
    save first, rate, c0

    if (first) then

      call system_clock(c0, rate)
      io_wallclocktime = 0.0_dp
      first = .false.
    else
      call system_clock(c1)
      io_wallclocktime = real(c1 - c0)/real(rate)
    endif
    return
  end function io_wallclocktime

  !================================================
  function io_file_unit()
    !================================================
    !! Returns an unused unit number
    !! so we can later open a file on that unit.
    !
    !================================================

    implicit none

    integer :: io_file_unit, unit
    logical :: file_open

    unit = 9
    file_open = .true.
    do while (file_open)
      unit = unit + 1
      inquire (unit, OPENED=file_open)
    end do

    io_file_unit = unit

    return
  end function io_file_unit

end module w90_io
