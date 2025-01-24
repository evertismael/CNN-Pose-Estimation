clear all; clc; close all;

% SYNTHETIC GENERATION OF DATASET OF RADAR IMAGES:

% Author: Epocoma 2024.
% Description: 
% This script reads a cvs file that contain the samples from the CMU-MoCap
% dataset that are related to a person walking. Notice that:
%     - Since de MoCap dataset is so big, we only provide a couple of
%     samples in 0005_cmu_mocap_dataset_Test. For a proper use, one must
%     download the official dataset fro mthe official website:
%     http://mocap.cs.cmu.edu/ 
%     - For each radar-frame, we create the following radar images: 
%     range-azimuth and range-elevation. Notice that later they are reduced
%     to extract the ROI defined in 2021ConShi_mPose.
%     - The synthetic radar signal is generated based on the joint
%     position only. Therefore, only one scatterer is used per bodypart.
%     Notice that this approach is not close to reality. However, we worked
%     on a new approach (not included in this project), that can be seen
%     here: https://ieeexplore.ieee.org/document/10804837 
%     - The radar images and the corresponding joint locations are
%     concatenated and saved to a file. In order not to save a huge file,
%     the dataset is divided into batches. The indexes of the
%     samples are included in the name of the file of each group.
%     - Since we only provide a couple of MoCap samples, we set here the
%     'batch_size' to 1.



% Import libraries and define the Mocap dataset location.
% -------------------------------------------------------------------------
addpath(genpath('../0010_matlab_main_imports/include'));
addpath(genpath('../0010_matlab_main_imports/mylibs'));
addpath(genpath('./functions'));

% folder with mocap data:
dataset_path = '../0005_cmu_mocap_dataset_test/';

% read dataset_file:
f_name = 'datasetwalk';
M = readtable([dataset_path, f_name, '.csv']);
M(1:3,:) % display in the console (to ensure the csv has been read)



% -------------------------------------------------------------------------
% Radar: Define the FMCW radar params to be used when generating the
% synthetic radar.
% -------------------------------------------------------------------------
[Ntx_enable] = deal([1 0 0]);
tx_seq = [1];
fc = 77e9;
rdrp = burst_prms(fc, Ntx_enable, tx_seq);
[rdr_p0, rdr_rot_ZYX_deg] = deal([0, -3,  0.8].', [0, 0, 0]); 
rdr = Radar(rdr_p0, rdr_rot_ZYX_deg, rdrp);


% Define the batch_size to divide the synthetic dataset file.
batch_size = 1; % 10;


% We start to treat each batch.
% ------------------------------------
for batch_idx = 1:10    

    % batch start/end
    [m_start, m_end] = deal(1+(batch_idx-1)*batch_size, batch_idx*batch_size);
    
    % --------------------------------------
    % output matrices: initialization:
    n_tpls = 0;
    roi_grids_all = double.empty(80,80,3,0);
    rm_azm_all = double.empty(80,80,0);
    rm_elevm_all = double.empty(80,80,0);
    jnts_xyz_all = double.empty(3,31,0);
    torso_xyz_all = double.empty(3,0);
    

    % We treat each sample of the MoCap Dataset in the batch:
    for idx = m_start:m_end

        % Retrieve the sample id's:
        [subject,trial] = deal(M{idx,['subject']}, M{idx,['trial']});
        description = M{idx,['description']}{1};
        
        subject = pad(num2str(subject),2,'left','0');
        trial = pad(num2str(trial),2,'left','0');
        fprintf('%d:  %s , %s, %s \n', idx, subject, trial, description)
        
        % -----------------------------------------------------------------
        % 0010: load mocap dataset:
        % -----------------------------------------------------------------
        mbody = MocapBody(dataset_path, subject, trial);
        mbody.id = 1;
        [sctrs, jnts] = mbody.get_scatterers();

        % -----------------------------------------------------------------
        % generate los measurements:
        % -----------------------------------------------------------------
        [opts.floor.mpath_enable, opts.ceiling.mpath_enable] = deal(false, false);
        [los, ~, ~] = scatterers_to_multipath_info(sctrs, rdr, opts);


        % -----------------------------------------------------------------
        % visualize scene:
        % -----------------------------------------------------------------
        mid = str2double(subject);
        [x_lim, y_lim, z_lim] = deal([-2, 2], [-3, 3], [0, 2]);
        scnMon = SceneMonitor(mid, x_lim, y_lim, z_lim);
        scnMon = scnMon.draw_radar(rdr);
        scnMon = scnMon.draw_jnts(jnts);
        scnMon = scnMon.draw_sctrs(sctrs);

        % animate:
        for fr_idx = 1:10:size(mbody.t_grid,2)
            scnMon = scnMon.update_jnts(jnts, fr_idx);
            scnMon = scnMon.update_sctrs(sctrs, fr_idx);
            pause(0.01);
        end
        
        % -----------------------------------------------------------------
        % decimate to reduce the data generated:
        % -----------------------------------------------------------------
        fr_sel_idx = 1:10:size(los.t_grid,2);
        los_dec.rm = los.rm(:,fr_sel_idx);
        los_dec.azm = los.azm(:,fr_sel_idx);
        los_dec.elm = los.elm(:,fr_sel_idx);
        los_dec.vm = los.vm(:,fr_sel_idx);
        los_dec.t_grid = los.t_grid(:,fr_sel_idx);
        
        jnts_dec.pos = jnts.pos(:,:,fr_sel_idx);
        jnts_dec.t_grid = jnts.t_grid(fr_sel_idx);
        jnts_dec.id = jnts.id;

        '';
        fig_a = figure;
        subplot(2,2,1); plot(los_dec.t_grid, los_dec.rm.'); title('Range vs time');
        subplot(2,2,2); plot(los_dec.t_grid, los_dec.vm.'); title('velocity vs time');
        subplot(2,2,3); plot(los_dec.t_grid, los_dec.azm.'); title('azimuth vs time');
        subplot(2,2,4); plot(los_dec.t_grid, los_dec.elm.'); title('elev vs time');
        '';
        
        % -----------------------------------------------------------------
        % create Range angle image:
        % -----------------------------------------------------------------
        show_images = true;
        [rm_azm, rm_elevm, roi_grids, torso_xyz, fig_b] = range_angles_images(...
                                        los_dec.rm, los_dec.azm, los_dec.elm, jnts_dec.pos, rdr, show_images);
     
        n_tpls = n_tpls + size(fr_sel_idx,2);  
        % -----------------------------------------------------------------
        % concatenate output data:
        % -----------------------------------------------------------------
        rm_azm_all = cat(3,rm_azm_all,rm_azm);
        rm_elevm_all = cat(3,rm_elevm_all,rm_elevm);
        roi_grids_all = cat(4,roi_grids_all,roi_grids);
        jnts_xyz_all = cat(3,jnts_xyz_all,jnts_dec.pos);
        torso_xyz_all = cat(2,torso_xyz_all,torso_xyz);
        '';

        %saveas(fig_a, ["erim.jpg"]);
        %saveas(scnMon.fig_scene, ["scene.jpg"]);

        close(fig_a);
        close(scnMon.fig_scene);
        close(fig_b);
    end

    disp(n_tpls)
    fout_name = ['./dataset/',f_name,'_batch_',num2str(m_start),'_',num2str(m_end),'.mat'];
    save(fout_name,'rm_azm_all','rm_elevm_all','roi_grids_all','jnts_xyz_all','torso_xyz_all');
end
