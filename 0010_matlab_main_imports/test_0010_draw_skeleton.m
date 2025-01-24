clear all; close all; clc;

% DISPLAY OF SKELETON JOINTS AND BONES OF A SAMPLE FROM A MOCAP DATASET.

% Author: Epocoma 2024.
% Description: 
% This short script shows how to read and plot a sample from
% the CMU dataset. To do so, it uses the first version of the 'SkeletonLib'
% librariry developed at OPERA-WCG.
% Notice that we provide only the p-code of such a library, since it
% will be properly released in the future.


% Add working paths and dataset path:
addpath(genpath('./include/'));
addpath(genpath('./mylibs/'));
dataset_path = '../0005_cmu_mocap_dataset_Test/';


% Define de data sample from the CMU mocap dataset.
% -------------------------------------------------------------------------
% mbody: contains main information.
% sctrs: length, orientation, center of scatterers.
% -------------------------------------------------------------------------
[subject, trial ] = deal('10','04');
mbody = MocapBody(dataset_path, subject, trial);
mbody.id = 1;
[sctrs, jnts] = mbody.get_scatterers();
fprintf('Total simple Frames %d , total simple duration: %.2f sec \n', mbody.Nfr, mbody.t_grid(end));


% Define the FMCW radar parameters to generate the synthetic signal.
% -------------------------------------------------------------------------
% Radar:
% -------------------------------------------------------------------------
[Ntx_enable, tx_seq] = deal([1 1 0], [1]);
rdrp = burst_prms(77e9, Ntx_enable, tx_seq);
[rdr_p0, rdr_rot_ZYX_deg] = deal([0, -3,  0.5].', [0, 0, 0]); 
rdr = Radar(rdr_p0, rdr_rot_ZYX_deg, rdrp);

% Define the object in charge of ploting the scene.
% -------------------------------------------------------------------------
% Scene Monitor: contains the figure and handlers to perform the animation
% -------------------------------------------------------------------------
idx = str2double(subject);
[x_lim, y_lim, z_lim] = deal([-2, 2], [-3, 3], [-1, 3]);
scnMon = SceneMonitor(idx, x_lim, y_lim, z_lim);
ceiling_height = 3;
scnMon = scnMon.draw_floor_ceiling(ceiling_height);
scnMon = scnMon.draw_radar(rdr);
scnMon = scnMon.draw_jnts(jnts);
scnMon = scnMon.draw_sctrs(sctrs);


% animate:
for fr_idx = 1:2:size(jnts.t_grid,2)
    scnMon = scnMon.update_jnts(jnts, fr_idx);
    scnMon = scnMon.update_sctrs(sctrs, fr_idx);
    pause(0.001);% pause(1/120);
end