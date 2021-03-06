classdef SARUtils
    
    methods (Static) 
        function displayReflector(reflector)
            % see  https://www.mathworks.com/matlabcentral/answers/5042-how-do-i-vary-color-along-a-2d-line
            x_curve = reflector.curve.z(1,:);
            y_curve = reflector.curve.z(2,:);
            z_curve = zeros(size(x_curve)); % this is a trick! 
            col_curve = reflector.coeff;  % This is the color, vary with x in this case.
            surface([x_curve;x_curve],[y_curve;y_curve],[z_curve;z_curve],[col_curve;col_curve],...
                    'facecol','no',...
                    'edgecol','interp',...
                    'linew',4);
            daspect([1 1 1]); colorbar; 
            cl = caxis; caxis([0, cl(2)]); 
        end
        
        function pointSrc = createPointSrc(ampl, pos)
            pointSrc.ampl = ampl; 
            pointSrc.pos = pos; 
        end
        
        function n_z = getUnitVectorPerpTo(vect_in)
            % use 3D cross product to calculate normal vector 
            % - it comes rotated counterclockwise from (zEnd - zStart), 
            % then drop the third coord

            vectCross = cross([0;0;1], [vect_in; 0]); 
            n_z = [vectCross(1); vectCross(2)]/norm(vectCross);  
        end        
        
        function scattField = getScattField(k, phi_xhat, reflector)
            [rows_z, cols_z] = size(reflector.curve.z); assert(rows_z == 2);
            xhat = [cos(phi_xhat); sin(phi_xhat)];
            k_inc = - k * xhat; 
            % sum(..., 1) works as columnwise dot(,), i.e., dot(,) at each z 
            % BTW dot here OK because args are real    
            % same as: q_inc_z = k * sum(repmat(xhat, 1, colsTheta) .* nz, 1);   
            curve = reflector.curve; 
            q_inc_z = - sum(repmat(k_inc, 1, cols_z) .* curve.nz, 1); 
            assert(all( abs(q_inc_z / k) > (1/3) ), 'incident wave too shallow'); 


            incWavePhase = sum(repmat(k_inc, 1, cols_z) .* curve.z, 1); 
            scattField.value = - k^2 * q_inc_z.^(-2) .* reflector.coeff .* exp(1i * incWavePhase); 
            scattField.normal_deriv = 1i * q_inc_z .* scattField.value; 
        end
        
        function traj = doFFP_curve(k, phi_refl, curve, field)

            traj.phi = phi_refl; 
            traj.ffp = nan(size(traj.phi));    

            [rows_z, cols_z] = size(curve.z); assert(rows_z == 2); 

            for iphi = 1:numel(traj.phi)
                phi = traj.phi(iphi); 

                % incident wave propagates from "-hat{x}"
                xhat_vector = [cos(phi); sin(phi)]; 
                k_xhat_z = k * sum(repmat(xhat_vector, 1, cols_z) .* curve.z, 1); 

                % outgoing wave is also a plane wave 
                outgoingExp.value = exp(-1i * k_xhat_z); 
                outgoingExp.gradient = -1i * k * [cos(phi); sin(phi)] * outgoingExp.value;
                outgoingExp.normal_deriv = sum(outgoingExp.gradient .* curve.nz, 1);

                % don't use dot(,) for complex numbers! it makes conj() of the first argument! 
                sum_for_ffp = sum(field.value .* outgoingExp.normal_deriv ... 
                                - field.normal_deriv .* outgoingExp.value); 

                % there is a factor of exp(1i * pi/4) / sqrt(8 * pi * k) in front of the integral 
                % I retain 1/sqrt(k) because I use different k's in SAR 
                traj.ffp(iphi) = sum_for_ffp / sqrt(k); 
                %{ 
                DEBUG
                if iphi < 5 
                    fprintf('Start k_xhat_z: %g, diffs = ', k_xhat_z(1)); 
                    fprintf('%8.5f ', k_xhat_z(1:5) - k_xhat_z(1)); 
                    fprintf('\n Mean curve = (%8.5f, %8.5f), result: %8.5f + i %8.5f\n', ... 
                                mean(curve.z(1)), mean(curve.z(2)), real(ffp), imag(ffp)); 
                end
                %}
            end

        end


        function I = buildRangeCompressionImg1D(yRange, k_band, x_hat, uinf)
            % x_hat is the argument of FFP, so its direction is that of the _reflected_ wave, 
            % while yRange is a vector of the _range_ coords of the target measured _from the source_
            % I choose y2D on a line passing through (0,0)           
            x_hat_inc = - x_hat; 
            y2D = [yRange * x_hat_inc(1); yRange * x_hat_inc(2)];  
            
            % create image for these 2D
            I = zeros(size(yRange)); 
            for iy = 1:numel(I)
                % dot(,) below is OK because both args are real        
                dotprod = dot(x_hat, y2D(:,iy)); 
                for il = 1:numel(uinf)
                    I(iy) = I(iy) + uinf(il) * exp(2i * k_band(il) * dotprod); 
                end
            end
        end        
        
        function I = buildRangeCompressionImg2D(y1, y2, k_band, x_hat, uinf)
            % x_hat is the argument of FFP, so its direction is that of the _reflected_ wave
            % create image
            [rowsI, colsI] = size(y1); 
            I = zeros(rowsI, colsI); 

            for il = 1:numel(uinf)
                dotprod = x_hat(1) * y1 + x_hat(2) * y2; 
                I = I + uinf(il) * exp(2i * k_band(il) * dotprod); 
            end  
        end        
        
        % phi_range corresponds to scattered field - see expression for x_hat
        function I = buildSARimage(y1, y2, k_band, phi_range, uinf)

            [rowsI, colsI] = size(y1); 
            I = zeros(rowsI, colsI); 

            for im = 1:numel(phi_range)
                phi = phi_range(im); 
                x_hat = [cos(phi); sin(phi)]; % scattered wave - don't need a minus
                for il = 1:numel(k_band)
                    dotprod = x_hat(1) * y1 + x_hat(2) * y2; 
                    I = I + uinf(im, il) * exp(2i * k_band(il) * dotprod); 
                end
            end  

        end

    end

end