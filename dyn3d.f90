!------------------------------------------------------------------------
!  Program     :            dyn3d
!------------------------------------------------------------------------
!  Purpose      : The main routine
!
!  Details      ：
!
!  Input        :
!
!  Input/output :
!
!  Output       :
!
!  Remarks      :
!
!  References   :
!
!  Revisions    :
!------------------------------------------------------------------------
!  whirl vortex-based immersed boundary library
!  SOFIA Laboratory
!  University of California, Los Angeles
!  Los Angeles, California 90095  USA
!  Ruizhi Yang, 2017 Nov
!------------------------------------------------------------------------

PROGRAM dyn3d

    !--------------------------------------------------------------------
    !  MODULE
    !--------------------------------------------------------------------
    USE module_constants
    USE module_data_type
    USE module_init_system
    USE module_ode_methods
    USE module_prescribed_motion
    USE module_embed_system
    USE module_config_files
    USE module_write_structure
    USE module_input_for_HERK

IMPLICIT NONE

    !--------------------------------------------------------------------
    !  INTERFACE FUNCTION
    !--------------------------------------------------------------------
    INTERFACE
        SUBROUTINE interface_func(t_i,y_i)
            USE module_constants, ONLY:dp
              REAL(dp),INTENT(IN)                           :: t_i
              REAL(dp),DIMENSION(:,:),INTENT(OUT)           :: y_i
        END SUBROUTINE interface_func
    END INTERFACE

    !--------------------------------------------------------------------
    !  Local variables
    !--------------------------------------------------------------------
    INTEGER                                   :: i,j,k,stage
    REAL(dp)                                  :: dt,tol
    CHARACTER(LEN = max_char)                 :: mode
    REAL(dp),DIMENSION(:),ALLOCATABLE         :: q_total,v_total
    REAL(dp),DIMENSION(:),ALLOCATABLE         :: q_out,v_out,vdot_out
    REAL(dp),DIMENSION(:),ALLOCATABLE         :: lambda_out
    REAL(dp)                                  :: h_out

    PROCEDURE(interface_func),POINTER         :: M => HERK_func_M
    PROCEDURE(interface_func),POINTER         :: G => HERK_func_G
    PROCEDURE(interface_func),POINTER         :: GT => HERK_func_GT
    PROCEDURE(interface_func),POINTER         :: gti => HERK_func_gti
    PROCEDURE(interface_func),POINTER         :: f => HERK_func_f


    !--------------------------------------------------------------------
    !  Input config data and construct body chain
    !--------------------------------------------------------------------

    ! add_body, add_joint and assemble them
!    CALL config_3d_hinged
    CALL config_2d_linkobj

    !--------------------------------------------------------------------
    !  Allocation
    !--------------------------------------------------------------------

    ALLOCATE(q_total(6*system%nbody))
    ALLOCATE(v_total(6*system%nbody))
    ALLOCATE(q_out(6*system%nbody))
    ALLOCATE(v_out(6*system%nbody))
    ALLOCATE(vdot_out(6*system%nbody))
    ALLOCATE(lambda_out(6*system%nbody))

    !--------------------------------------------------------------------
    !  Construct and init system
    !--------------------------------------------------------------------

    ! initialize system
    CALL init_system

    ! write initial condition
    WRITE(*,*) 'At t=0, body position is:'
    DO i = 1, system%nbody
        WRITE(*,'(A,I5,A)',ADVANCE="NO") "body ",i," :"
        DO j = 1, 6
            WRITE(*,'(F9.5)',ADVANCE="NO") system%soln%y(1,6*(i-1)+j)
        END DO
        WRITE(*,'(/)')
    END DO
    WRITE(*,*) 'At t=0, body velocity is:'
    DO i = 1, system%nbody
        WRITE(*,'(A,I5,A)',ADVANCE="NO") "body ",i," :"
        DO j = 1, 6
            WRITE(*,'(F9.5)',ADVANCE="NO") &
                system%soln%y(1,6*system%nbody+6*(i-1)+j)
        END DO
        WRITE(*,'(/)')
    END DO
    WRITE(*,*) '--------------------------------------------------------'

    !--------------------------------------------------------------------
    !  Solve ode and embed system using the last solution
    !--------------------------------------------------------------------

    ! HERK solver coefficients
    tol = 1e-4_dp
    stage = 3
    dt = system%params%dt

    ! do loop until nstep
    DO i = 2, 2
        ! construct time
        system%soln%t(i) = system%soln%t(i-1) + dt

    ! construct input for HERK
        DO j = 1, system%nbody
            q_total(6*(j-1)+1:6*j) = body_system(j)%q(:,1)
            v_total(6*(j-1)+1:6*j) = body_system(j)%v(:,1)
        END DO


        CALL HERK(system%soln%t(i-1), q_total, v_total, 6*system%nbody, &
                  6*system%nbody, dt, tol, stage, M, f, G, &
                  GT, gti, q_out, v_out, vdot_out, lambda_out, h_out)


        ! update the system state with ode solution
        q_total(:) = 0.0_dp
        v_total(:) = 0.0_dp

        ! update body chain using the solution
        DO j = 1, system%nbody
            body_system(j)%q(:,1) = q_out(6*(j-1)+1:6*j)
            body_system(j)%v(:,1) = v_out(6*(j-1)+1:6*j)
            body_system(j)%c(:,1) = vdot_out(6*(j-1)+1:6*j)
        END DO

!        ! update the current setup of the system
!        CALL embed_system

        ! write final solution
        IF(i == 2) THEN
            WRITE(*,*) 'At t= ',system%soln%t(i),' body position is:'
            DO k = 1, system%nbody
                WRITE(*,'(A,I5,A)',ADVANCE="NO") "body ",k," :"
                DO j = 1, 6
                    WRITE(*,'(F9.5)',ADVANCE="NO") system%soln%y(i,6*(k-1)+j)
                END DO
                WRITE(*,'(/)')
            END DO
            WRITE(*,*) 'At t=0, body velocity is:'
            DO k = 1, system%nbody
                WRITE(*,'(A,I5,A)',ADVANCE="NO") "body ",k," :"
                DO j = 1, 6
                    WRITE(*,'(F9.5)',ADVANCE="NO") &
                        system%soln%y(i,6*system%nbody+6*(k-1)+j)
                END DO
                WRITE(*,'(/)')
            END DO
        END IF

    END DO

    !--------------------------------------------------------------------
    !  Write data
    !--------------------------------------------------------------------
    CALL write_structure

    !--------------------------------------------------------------------
    !  Deallocation
    !--------------------------------------------------------------------
    DEALLOCATE(q_total)
    DEALLOCATE(v_total)
    DEALLOCATE(q_out)
    DEALLOCATE(v_out)
    DEALLOCATE(vdot_out)
    DEALLOCATE(lambda_out)


END PROGRAM dyn3d