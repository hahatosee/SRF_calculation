%% Function for calculating the self-resonant frequency (SRF) of spherical solenoid coils

%  Created by Wenshen Zhou on 22 Apr 2019

%  Introduction:
%  The code can be used for calculating the SRF of spherical solenoids. 
%  Inductance (L)%  and capacitance (C) are calculated individually, then 
%  the SRF is calculated as 1/(2*pi*sqrt(L*C)). The methods for calculating
%  L and C are illustrated in the paper: W. Zhou, and S. Y. Huang, "An 
%  accurate model for fast calculating the resonant frequency of an irregular 
%  solenoid".

% Input:
% N:               number of turns of the solenoid
% N1:              tapering factor of the spherical solenoid
% f1:              frequecy for calculating inductance, a low f1 is usually used.
% r_w:             radius of the wire
% radius:          radius of the solenoid
% s:               number of segments of the coil
% step:            the step size for meshing the computation domain

% Output:
% L:               inductance of the solenoid        
% C:               capacitance of the solenoid
% f_res:           self resonant frequency of the solenoid

function [L, C, f_res] = func_SRF_calculation_spherical(N, N1, f1, r_w, radius, s, step)

L_separate = zeros(1,N);    % inductance of each turns

mu_0 = 4*pi*10^-7;
epsilon_0 = 8.854187817e-12;
mu_r = 1;
rho = 1.72e-8;           % resistivity of copper
sigma = 5.96e7;          % conductivity of copper
d = 2*r_w;               % diameter of wire
D = 2*radius;            % diameter of coil

l_coil = len_sin_helix(radius,N1,-N*pi,N*pi);    % length of the wire of the solenoid
L_int = mu_0*(l_coil/N)/(8*pi);                  % internal inductance of each turn


%% Calculation of inductance of the solenoid
T = 1/f1;           % period
speed = 3e8;        % speed of EM wave
lambda = speed/f1;  % wavelength at frequency f1
phi0 = 0;           % initial phase

% Define the solenoid using parametric equations
n = 0;
for t = -N*pi:2*N*pi/s:N*pi
    n = n+1;
    
    coil(n,1) = radius*cos(t/10)*cos(t);      % X coordinate of point n
    coil(n,2) = radius*cos(t/10)*sin(t);      % Y coordinate of point n
    coil(n,3) = radius*sin(t/10);             % Z coordinate of point n
    
end
dl = coil(2:s+1, :) - coil(1:s, :);           % vectors of the coil segments

% Current at each segment
time = 0;
l = 0;
Ic(1) = 1;
for ic = 2:s
    l = l + abs(dl(ic-1));
    Ic(ic) = cos(2*pi*f1*time-l/lambda+phi0);
end

B = [0 0 0];
n = 0;
boundary = 0.01;
% calculation domain in x, y, and z direction
x_start = -(radius+boundary);
x_stop = radius+boundary;
x_span = (x_stop-x_start)/step+1;
y_start = -(radius+boundary);
y_stop = radius+boundary;
y_span = (y_stop-y_start)/step+1;
z_start = -(radius+boundary);
z_stop = radius+boundary;
z_span = (z_stop-z_start)/step+1;

% Calculate the B field generated by the solenoid coil with Biot-Savart Law
for x = x_start:step:x_stop
    n = n+1;
    m = 0;
    l = 0;
    for y = y_start:step:y_stop
        m = m+1;
        l = 0;
        for z = z_start:step:z_stop
            l = l+1;
            [B_mag(n,m,l) Bz(n,m,l)]= calculateB(x, y, z, s, Ic, coil, dl);
        end
    end
end


t1 = -(N-1)*pi:2*pi:(N-1)*pi;   % the parameter corresponding to the transverse middle plane
%    z_O = pitch*t1/(2*pi);              % for cylindrical solenoids
z_O = radius*sin(t1/10);        % for spherical solenoids
z1 = zeros(x_span,y_span,N);    % z-coordinates of the points on calculation surface
z3_plot = zeros(x_span,y_span);
B_map = zeros(x_span,y_span,N); % matrix to decide whether a point is inside the coil, 1->'yes', 0->'no'

% Calculate the z-coordinates of the points on calculation surface
for k = 1:N
    n = 0;
    for x = x_start:step:x_stop
        n = n+1;
        m = 0;
        for y = y_start:step:y_stop
            m = m+1;
            if x==0 && y==0
                theta = pi + (k-(N-1))*2*pi;
            elseif y>=0
                theta = acos(x/sqrt(x^2+y^2)) + (k-(N-1))*2*pi;
            else
                theta = acos(-x/sqrt(x^2+y^2))+ pi + (k-(N-1))*2*pi;
            end
            
            Rc = radius*cos(theta/10);    
            
            if x^2+y^2<=(Rc-r_w)^2
                B_map(n,m,k) = 1;
                z_R1 = radius*sin(theta/10);  
                z1(n,m,k) = (z_R1-z_O(k))*sqrt(x^2+y^2)/Rc+z_O(k);
            else
                B_map(n,m,k) = 0;
            end
        end
    end
end


Area = pi*Rc.^2;                % area of the transverse-middle-planes
phi_area = zeros(1,N);          % magnetic flux of single calculation surfaces
phi_total = 0;                  % total magnetic flux
L_total = 0;                    % total inductance
B_area = zeros(x_span,y_span,N);% B field of single calculation surfaces



for k = 1:N
    % Calculate the magnetic flux at all the calculation surfaces
    for n = 1:x_span
        for m = 1:y_span
            for iz = 1:z_span
                z(iz) = z_start + step*(iz-1);
                if z(iz)>=z1(n,m,k)
                    B_area(n,m,k) = Bz(n,m,iz);
                    break;
                end
            end
            if B_map(n,m,k) == 1
                phi_area(k) = phi_area(k) + B_area(n,m,k)*step^2;
            end
        end
    end
    
    % Calculate the inductance of each loop
    Ic_area(k) = Ic((2*k-1)*s/(2*N)+1);             % current at the middle segment of each loop
    L_separate(k) = phi_area(k)/Ic_area(k);         % inductance of each loop
    L_total = L_total+L_separate(k)+L_int(k);       % total inductance of the solenoid
    phi_total = phi_total + phi_area(k);
end

L = L_total;


%% Calculation of capacitance of the solenoid
% for cylindrical solenoid with uniform pitches
Sph_position = zeros(N,3);
n2 = 0;
for t2 = -(N-1)*pi:2*pi:3*pi
    n2 = n2 + 1;
    Rc_s(n2) = radius*cos(t2/N1);          % radius of circle in xy-plane
end

for n3 = 1:(N-1)
    R_NN(n3) = 1/2*(Rc_s(n3)+Rc_s(n3+1));  % radius of circle for nearest-neighbour C calculation
end

for n3 = 1:(N-2)
    R_2nd_NN(n3) = 1/2*(Rc_s(n3)+Rc_s(n3+2));  % radius of circle for 2nd-nearest-neighbour C calculation
end

for n4 = 1:N
    Sph_position(n4,:) = coil(1+(n4-1)*s/N,:); % position of the first element of each turn
end
Sph_position(N+1,:) = coil(s,:);

C_NN_total = 0;
C_2nd_NN_total = 0;

for n4 = 1:(N-1)                     % nearest-neighbout C calculation
    pitch_NN(n4,:) = 1/2 * (norm(Sph_position(n4+1)-Sph_position(n4))+norm(Sph_position(n4+2)-Sph_position(n4+1)));
    C_sph_NN(n4,:) = 2*epsilon_0*pi^2*R_NN(n4)/(acosh(pitch_NN(n4,:)/d));
    C_NN_total = C_NN_total + 1/C_sph_NN(n4,:);
end

for n4 = 1:(N-2)                     % 2nd-nearest-neighbour C calculation
    pitch_2nd_NN(n4,:) = 1/2 * (norm(Sph_position(n4+2)-Sph_position(n4))+norm(Sph_position(n4+3)-Sph_position(n4+1)));
    C_sph_2nd_NN(n4,:) = 2*epsilon_0*pi^2*R_2nd_NN(n4)/(acosh(pitch_2nd_NN(n4,:)/d));
    C_2nd_NN_total = C_2nd_NN_total + 1/C_sph_2nd_NN(n4,:);
end

C = 1/C_NN_total + 1/C_2nd_NN_total;   % total capacitance

%% Calculation of SRF
f_res = 1/(2*pi*sqrt(L*C));
    
end

%% Functions

%% Function to calculate the length of each of of a spherical solenoid

% Input: 
% radius:           radiu of the spherical solenoid
% N1:               tapering factor of the spherical solenoid
% t1,t2:            starting and ending position variable, N = (t2-t1)/(2*pi) is the number of turns of the solenoid

% Output:
% Len_loop:         1*N array, length of each turns of the N turn spherical solenoid

function [Len_loop] = len_sin_helix(radius,N1,t1,t2)
    N = (t2-t1)/(2*pi);
    for n = 1:N
        %Len_loop(n) = integral(@diff_sin_helix,t1+(n-1)*2*pi,t1+n*2*pi);
        Len_loop(n) = integral(@(t)diff_sin_helix(radius,N1,t),t1+(n-1)*2*pi,t1+n*2*pi);
    end
end


%% Function to calculate the diffrential of the parametric equation of a 
%  spherical solenoid for calculating the length of each turn

% Input:
% radius:           radiu of the spherical solenoid
% N1:               tapering factor of the spherical solenoid
% t:                the position variable

% Output:
% dy:               square root of the quadratic sums of the diffrential of
%                   x, y and z parametric equation. The length of each turn
%                   can be calculated with the integral of dy 

function dy = diff_sin_helix(radius,N1,t)
    x_d = -radius.*(1/N1*sin(t/N1).*cos(t)+cos(t/N1).*sin(t));
    y_d = radius.*(cos(t/N1).*cos(t)-1/N1*sin(t/N1).*sin(t));
    z_d = radius*1/N1*cos(t/N1);
    dy = sqrt(x_d.^2+y_d.^2+z_d.^2);
end

