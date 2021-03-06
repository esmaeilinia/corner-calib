classdef CCheckerboard < CPattern & CPlane3D
    %CCheckerboard 3D pattern formed by 1 checkered plane
    %   Constructor:
    %   pol = CCheckerboard( R, t, L, N )
    %       L is the size of corner side
    %       N is the number of squares drawn in pattern
    %   
    %   h    - size of drawn squares
    %   face - a polygon
    %   p2D  - a 2xN^2 array with coordinates of squares in 2D frame
    %   p3D  - a 3xN^2 array with coordinates of squares in 3D World frame
    
    properties (SetAccess = protected) % (Read-only)
        h       % Size of drawn squares
        Ndiv    % Number of divisions (square)
        
        p2D     % Set of grid points
    end
    
    methods
        % Constructor
        function obj = CCheckerboard( L, R, t, Ndiv )
            if ~exist('R','var')
%                 R = eye(3);
                R = RotationZ(deg2rad(45))*RotationY(deg2rad(45));
            end
            if ~exist('t','var')
                t = zeros(3,1);
            end
            if ~exist('L','var')
                L = 1;
            end
            if ~exist('Ndiv','var')
                Ndiv = 10;
            end
            obj = obj@CPlane3D( R, t );
            obj = obj@CPattern( R, t );

            obj.L = L;
            obj.Ndiv = Ndiv;
            obj.h = L / Ndiv;
            obj.NF = 1;
            
            % Create face: Single
            ref_R = eye(3);
            face_R = {ref_R};
            p = [ 0 0 ; L 0 ; L L ; 0 L ]' - L/2;
            for i=1:obj.NF
                obj.face{i} = CPolygon( R * face_R{i}, t, p );
            end
            
            obj.p2D = obj.createGrid;
            obj.p3D = obj.transform2Dto3D( obj.p2D );
        end
        
        % Create grid from object set properties
        function p2D = createGrid( obj )
            p = obj.face{1}.p;
            lower = min(p,[],2);
            upper = max(p,[],2);
            [X,Y] = meshgrid( lower(1):obj.h:upper(1),...
                            lower(2):obj.h:upper(2) );
            p2D = [ X(:), Y(:) ]'; % Give p2D points X-line by line (up-down)
        end
        
        % Get array of projection of interest points in pattern
        function [uv_proj, uv_pixels] = getProjection( obj, SimCamera )
            [uv_proj, uv_pixels] = SimCamera.projectPattern( obj );
        end
        
        function co = getCorrespondence( obj, Rig )
            % Get Checkerboard grid
            grid_pts = obj.p2D;
            
            % Camera data
            [~, uv_pixels] = obj.getProjection( Rig.Camera );

            % Lidar data (in mm)
            LRF_pts = 1000 * cell2mat( obj.getScan( Rig.Lidar ) );
            
            % Robust simulation
            if size(uv_pixels,2)<size(grid_pts,2) || size(LRF_pts,2)<=1
                warning('Checkerboard: Out of FOV')
                co = [];
            else
                T_plane = obj.getCalibPlane( grid_pts, uv_pixels, Rig.Camera.K );
                co = CCheckerboardObservation( T_plane, LRF_pts);
            end
        end
        
        % Pattern 3D representation
        function h = plot3( obj ) % Plot checkerboard in 3D space
            obj.face{1}.plot3;
            h = plot3( obj.p3D(1,:), obj.p3D(2,:), obj.p3D(3,:), '*' );
%             quiver3( obj.t(1),obj.t(2),obj.t(3),...
%                      obj.n(1),obj.n(2),obj.n(3) );
        end
        
        % Project the 3D points to the image and estimate the plane eq.
        function T_plane = getCalibPlane( obj, grid_pts, img_pts, K)
            
            % Set the parameters for the plane equation extraction
            fc       = [K(1,1); K(2,2)];
            cc       = [K(1,3); K(2,3)];
            kc       = zeros(5,1);
            alpha_c  = 0;
            max_iter = 20;
            th_cond  = 1000000;
            
            Npts = size( grid_pts,2 );
            % Project the 3D points to the image plane
            grid_pts = [ grid_pts ; zeros(1,Npts) ];
            
            [omc,t,R] = compute_extrinsic_init(img_pts,grid_pts,fc,cc,kc,alpha_c);
            [omc,t,R,JJ_kk] = compute_extrinsic_refine(omc,t,img_pts,grid_pts,fc,cc,kc,alpha_c,max_iter,th_cond);
            
            T_plane = [[R t*1000];[0 0 0 1]]; % They work in mm            
        end     

    end
end