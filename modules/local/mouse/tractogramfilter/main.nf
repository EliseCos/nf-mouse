process MOUSE_TRACTOGRAMFILTER {
    tag "$meta.id"
    label 'process_high'

    container "scilus/scilpy:2.2.0_cpu"

    input:
        tuple val(meta), path(ANO), path(trk)

    output:
        tuple val(meta), path("*_tract-*_tractogram.trk")   , emit: trk_filtered
        tuple val(meta), path("*_in.nii.gz")                , emit: mask_includ
        tuple val(meta), path("*_ex.nii.gz")                , emit: mask_exclud
        tuple val(meta), path("*_tracking_mqc.png")         , emit: mqc
        tuple val(meta), path("*_tracking_stats_mqc.json")  , emit: mqc_json
        path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = task.ext.first_suffix ?: task.ext.suffix
    def mode_mask1 = task.ext.mode_mask1 ?: "any"
    def mode_mask2 = task.ext.mode_mask2 ?: "any"
    def criteria_mask1 = task.ext.criteria_mask1 ?: "include"
    def criteria_mask2 = task.ext.criteria_mask2 ?: "exclude"
    def alpha = task.ext.alpha ?: "0.6"
    def labels_ex = task.ext.labels_ids_ex
    def labels_in = task.ext.labels_ids_in
    
    def run_qc = task.ext.run_qc ? task.ext.run_qc : false

    """
    scil_labels_combine ${prefix}_${suffix}_in.nii.gz --merge_groups \
        --volume_ids ${ANO} ${labels_in} -f
    scil_labels_combine ${prefix}_${suffix}_ex.nii.gz --merge_groups \
        --volume_ids ${ANO} ${labels_ex} -f

    scil_tractogram_filter_by_roi ${trk} ${prefix}__tmp.trk \
        --drawn_roi ${prefix}_${suffix}_in.nii.gz ${mode_mask1} ${criteria_mask1} \
        --drawn_roi ${prefix}_${suffix}_ex.nii.gz ${mode_mask2} ${criteria_mask2}
    
    scil_bundle_reject_outliers ${prefix}__tmp.trk ${prefix}_tract-${suffix}_tractogram.trk --alpha ${alpha}

    rm -f ${prefix}__tmp.trk

    if $run_qc;
    then

        # Create dummy image for visualization
        scil_tractogram_compute_density_map ${prefix}_tract-${suffix}_tractogram.trk \
            tmp_anat_qc.nii.gz -f

        scil_viz_bundle_screenshot_mosaic tmp_anat_qc.nii.gz ${prefix}_tract-${suffix}_tractogram.trk\
            ${prefix}__${suffix}_tracking_mqc.png --opacity_background 1 --light_screenshot
        scil_tractogram_print_info ${prefix}_tract-${suffix}_tractogram.trk >> ${prefix}__${suffix}_tracking_stats_mqc.json
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(uv pip -q -n list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = task.ext.first_suffix ?: task.ext.suffix
    """
    scil_labels_combine -h
    scil_tractogram_filter_by_roi -h
    scil_bundle_reject_outliers -h

    touch ${prefix}_tract-${suffix}_tractogram.trk

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(uv pip -q -n list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
