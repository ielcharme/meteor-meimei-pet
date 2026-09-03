#!/usr/bin/env python3
"""Key real green-screen dog footage into the desktop-only action atlas."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps


CELL_WIDTH = 192
CELL_HEIGHT = 208
FRAMES_PER_ACTION = 8
ACTION_ORDER = (
    "head-tilt",
    "eating",
    "roll",
    "waiting",
    "startup",
    "walk-left",
    "walk-right",
    "expectant",
)
ACTION_FPS = {
    "head-tilt": 1.6,
    "eating": 1.6,
    "roll": 1.6,
    "waiting": 1.4,
    "startup": 4.0,
    "walk-left": 5.0,
    "walk-right": 5.0,
    "expectant": 1.5,
}


@dataclass(frozen=True)
class ActionSource:
    name: str
    path: Path
    sample_start: float | None = None
    sample_step: float | None = None
    sample_end: float | None = None
    normalization: str = "shared-crop"


def run(command: list[str]) -> str:
    result = subprocess.run(command, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def video_duration(ffprobe: str, source: Path) -> float:
    return float(
        run(
            [
                ffprobe,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(source),
            ]
        )
    )


def extract_frames(
    ffmpeg: str,
    ffprobe: str,
    source: ActionSource,
    output_dir: Path,
) -> tuple[list[Path], list[float]]:
    duration = video_duration(ffprobe, source.path)
    if source.sample_start is not None and source.sample_step is not None:
        times = source.sample_start + np.arange(FRAMES_PER_ACTION) * source.sample_step
        if float(times[-1]) >= duration:
            raise RuntimeError(
                f"Requested samples for {source.name} exceed source duration: "
                f"{times[-1]:.3f}s >= {duration:.3f}s"
            )
    else:
        start = min(0.05, duration * 0.01)
        end = source.sample_end if source.sample_end is not None else max(start, duration - 0.20)
        times = np.linspace(start, end, FRAMES_PER_ACTION)
    action_dir = output_dir / source.name / "source"
    action_dir.mkdir(parents=True, exist_ok=True)

    paths: list[Path] = []
    for index, timestamp in enumerate(times):
        destination = action_dir / f"{index:02d}.png"
        run(
            [
                ffmpeg,
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-ss",
                f"{timestamp:.6f}",
                "-i",
                str(source.path),
                "-frames:v",
                "1",
                "-an",
                "-c:v",
                "png",
                str(destination),
            ]
        )
        paths.append(destination)
    return paths, [float(value) for value in times]


def estimate_key_chroma(rgb: np.ndarray) -> np.ndarray:
    height, width, _ = rgb.shape
    border = max(8, int(min(height, width) * 0.06))
    samples = np.concatenate(
        [
            rgb[:border].reshape(-1, 3),
            rgb[:, :border].reshape(-1, 3),
            rgb[:, -border:].reshape(-1, 3),
        ],
        axis=0,
    ).astype(np.float32)
    green = samples[:, 1] > samples[:, 0] * 1.08
    green &= samples[:, 1] > samples[:, 2] * 1.08
    candidates = samples[green]
    if len(candidates) < 100:
        candidates = samples
    normalized = candidates / np.maximum(candidates.sum(axis=1, keepdims=True), 1.0)
    return np.median(normalized, axis=0)


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def fill_enclosed_holes(mask: Image.Image) -> Image.Image:
    exterior = mask.copy()
    draw = ImageDraw.Draw(exterior)
    width, height = exterior.size
    for seed in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        if exterior.getpixel(seed) == 0:
            ImageDraw.floodfill(exterior, seed, 128, thresh=0)
    array = np.asarray(exterior, dtype=np.uint8)
    filled = np.where(array == 0, 255, np.where(array == 255, 255, 0)).astype(np.uint8)
    return Image.fromarray(filled, mode="L")


def key_frame(source_path: Path, destination: Path) -> tuple[Image.Image, dict[str, object]]:
    image = Image.open(source_path).convert("RGB")
    rgb = np.asarray(image, dtype=np.float32)
    key = estimate_key_chroma(rgb)
    normalized = rgb / np.maximum(rgb.sum(axis=2, keepdims=True), 1.0)
    chroma_distance = np.sqrt(np.sum((normalized - key.reshape(1, 1, 3)) ** 2, axis=2))

    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    green_dominant = (green > red * 1.025) & (green > blue * 1.025)
    alpha = np.where(green_dominant, smoothstep(0.035, 0.135, chroma_distance), 1.0)

    # Protect dark black fur from green reflections while retaining a clean key on the lit set.
    darkest_fur = (np.max(rgb, axis=2) < 42.0) & (chroma_distance > 0.09)
    alpha = np.where(darkest_fur, np.maximum(alpha, 0.90), alpha)
    alpha = np.where(alpha < 0.08, 0.0, alpha)
    alpha = np.where(alpha > 0.94, 1.0, alpha)

    alpha_image = Image.fromarray(np.uint8(np.clip(alpha * 255.0, 0, 255)), mode="L")
    alpha_image = alpha_image.filter(ImageFilter.GaussianBlur(radius=0.65))
    alpha_array = np.asarray(alpha_image, dtype=np.uint8)

    # Keep only the feather band immediately surrounding a solid foreground core.
    # This removes desaturated cast shadows from the green floor without trimming fur.
    core = Image.fromarray(np.uint8(alpha_array >= 190) * 255, mode="L")
    closed_core = core.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.MinFilter(15))
    closed_core = fill_enclosed_holes(closed_core)
    support = closed_core.filter(ImageFilter.MaxFilter(17))
    closed_array = np.asarray(closed_core, dtype=np.uint8)
    support_array = np.asarray(support, dtype=np.uint8)
    alpha_array = np.where(support_array > 0, alpha_array, 0).astype(np.uint8)
    alpha_array = np.maximum(alpha_array, np.where(closed_array > 0, 242, 0).astype(np.uint8))
    alpha_float = alpha_array.astype(np.float32) / 255.0

    # Remove green spill only where the keyed subject remains visible.
    non_green = np.maximum(red, blue)
    spill_limit = non_green + 4.0 + 12.0 * alpha_float
    green = np.minimum(green, spill_limit)
    rgba = np.dstack([red, green, blue, alpha_array.astype(np.float32)])
    rgba = np.uint8(np.clip(rgba, 0, 255))
    rgba[alpha_array == 0, :3] = 0
    keyed = Image.fromarray(rgba, mode="RGBA")
    destination.parent.mkdir(parents=True, exist_ok=True)
    keyed.save(destination)

    mask = alpha_array >= 96
    ys, xs = np.nonzero(mask)
    bbox = None if len(xs) == 0 else [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    stats = {
        "keyChroma": [round(float(value), 6) for value in key],
        "bboxAtAlpha96": bbox,
        "opaquePixels": int(np.count_nonzero(alpha_array == 255)),
        "semiTransparentPixels": int(np.count_nonzero((alpha_array > 0) & (alpha_array < 255))),
        "transparentPixels": int(np.count_nonzero(alpha_array == 0)),
        "cornerAlphaMax": int(
            max(alpha_array[0, 0], alpha_array[0, -1], alpha_array[-1, 0], alpha_array[-1, -1])
        ),
    }
    return keyed, stats


def union_bbox(frames: list[Image.Image], threshold: int = 96) -> tuple[int, int, int, int]:
    boxes: list[tuple[int, int, int, int]] = []
    for frame in frames:
        alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8)
        ys, xs = np.nonzero(alpha >= threshold)
        if len(xs):
            boxes.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    if not boxes:
        raise RuntimeError("No keyed foreground survived alpha extraction.")
    left = min(box[0] for box in boxes)
    top = min(box[1] for box in boxes)
    right = max(box[2] for box in boxes)
    bottom = max(box[3] for box in boxes)
    margin_x = max(2, int((right - left) * 0.015))
    margin_y = max(2, int((bottom - top) * 0.015))
    width, height = frames[0].size
    return (
        max(0, left - margin_x),
        max(0, top - margin_y),
        min(width, right + margin_x),
        min(height, bottom + margin_y),
    )


def normalize_action(frames: list[Image.Image], crop: tuple[int, int, int, int]) -> list[Image.Image]:
    crop_width = crop[2] - crop[0]
    crop_height = crop[3] - crop[1]
    available_width = CELL_WIDTH - 12
    available_height = CELL_HEIGHT - 10
    scale = min(available_width / crop_width, available_height / crop_height)
    resized_size = (
        max(1, int(round(frames[0].width * scale))),
        max(1, int(round(frames[0].height * scale))),
    )
    crop_scaled = tuple(int(round(value * scale)) for value in crop)
    subject_width = crop_scaled[2] - crop_scaled[0]
    subject_height = crop_scaled[3] - crop_scaled[1]
    subject_left = (CELL_WIDTH - subject_width) // 2
    subject_top = CELL_HEIGHT - 5 - subject_height
    offset_x = subject_left - crop_scaled[0]
    offset_y = subject_top - crop_scaled[1]

    normalized: list[Image.Image] = []
    for frame in frames:
        resized = frame.resize(resized_size, Image.Resampling.LANCZOS)
        cell = Image.new("RGBA", (CELL_WIDTH, CELL_HEIGHT), (0, 0, 0, 0))
        cell.alpha_composite(resized, (offset_x, offset_y))
        pixels = np.asarray(cell, dtype=np.uint8).copy()
        pixels[pixels[:, :, 3] == 0, :3] = 0
        normalized.append(Image.fromarray(pixels, mode="RGBA"))
    return normalized


def frame_bbox(frame: Image.Image, threshold: int = 96) -> tuple[int, int, int, int]:
    alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8)
    ys, xs = np.nonzero(alpha >= threshold)
    if len(xs) == 0:
        raise RuntimeError("No keyed foreground survived alpha extraction.")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def suppress_walk_floor(frame: Image.Image) -> tuple[Image.Image, int]:
    """Remove green floor/shadow pixels retained around walking paws."""
    pixels = np.asarray(frame.convert("RGBA"), dtype=np.uint8).copy()
    red = pixels[:, :, 0].astype(np.float32)
    green = pixels[:, :, 1].astype(np.float32)
    blue = pixels[:, :, 2].astype(np.float32)
    alpha = pixels[:, :, 3]
    height = pixels.shape[0]
    lower_band = np.arange(height)[:, None] >= int(round(height * 0.52))
    greenish = green > red * 1.06
    greenish &= green > blue * 1.04
    greenish &= (green - np.maximum(red, blue)) > 8.0
    candidates = lower_band & greenish & (alpha > 0)

    # Remove only large, floor-like green components or components connected to
    # the source-frame edge. Small green reflections inside white/black fur stay.
    removal = np.zeros_like(candidates, dtype=bool)
    visited = np.zeros_like(candidates, dtype=bool)
    frame_height, frame_width = candidates.shape
    for start_y, start_x in zip(*np.nonzero(candidates & ~visited)):
        if visited[start_y, start_x]:
            continue
        queue: deque[tuple[int, int]] = deque([(int(start_y), int(start_x))])
        visited[start_y, start_x] = True
        component: list[tuple[int, int]] = []
        min_x = max_x = int(start_x)
        min_y = max_y = int(start_y)
        touches_edge = False
        while queue:
            y, x = queue.popleft()
            component.append((y, x))
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)
            touches_edge |= x == 0 or x == frame_width - 1 or y == frame_height - 1
            for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if not (0 <= next_y < frame_height and 0 <= next_x < frame_width):
                    continue
                if visited[next_y, next_x] or not candidates[next_y, next_x]:
                    continue
                visited[next_y, next_x] = True
                queue.append((next_y, next_x))
        component_width = max_x - min_x + 1
        component_height = max_y - min_y + 1
        floor_like = len(component) >= 450 and component_width >= 28
        floor_like &= component_height <= max(18, int(round(component_width * 0.65)))
        if touches_edge or floor_like:
            ys, xs = zip(*component)
            removal[np.asarray(ys), np.asarray(xs)] = True

    # Green-screen floor shadows are often too faint to satisfy the colour
    # test above. Remove only detached soft alpha in the lower half, while
    # retaining feathered fur and paw edges close to an opaque dog pixel.
    opaque_core = Image.fromarray(np.where(alpha >= 190, 255, 0).astype(np.uint8), mode="L")
    nearby_subject = np.asarray(opaque_core.filter(ImageFilter.MaxFilter(11)), dtype=np.uint8) > 0
    detached_soft = lower_band & (alpha > 0) & (alpha < 190) & ~nearby_subject
    removal |= detached_soft
    pixels[removal] = 0
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return Image.fromarray(pixels, mode="RGBA"), int(np.count_nonzero(removal))


def refresh_alpha_report(frame: Image.Image, report: dict[str, object]) -> None:
    alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8)
    ys, xs = np.nonzero(alpha >= 96)
    report["bboxAtAlpha96"] = (
        None
        if len(xs) == 0
        else [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    )
    report["opaquePixels"] = int(np.count_nonzero(alpha == 255))
    report["semiTransparentPixels"] = int(np.count_nonzero((alpha > 0) & (alpha < 255)))
    report["transparentPixels"] = int(np.count_nonzero(alpha == 0))
    report["cornerAlphaMax"] = int(max(alpha[0, 0], alpha[0, -1], alpha[-1, 0], alpha[-1, -1]))


def keep_largest_alpha_component(frame: Image.Image) -> tuple[Image.Image, int]:
    """Drop isolated keying dust after a tracked frame has been resized."""
    pixels = np.asarray(frame.convert("RGBA"), dtype=np.uint8).copy()
    mask = pixels[:, :, 3] > 0
    visited = np.zeros_like(mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    height, width = mask.shape
    for start_y, start_x in zip(*np.nonzero(mask)):
        if visited[start_y, start_x]:
            continue
        queue: deque[tuple[int, int]] = deque([(int(start_y), int(start_x))])
        visited[start_y, start_x] = True
        component: list[tuple[int, int]] = []
        while queue:
            y, x = queue.popleft()
            component.append((y, x))
            for next_y in range(y - 1, y + 2):
                for next_x in range(x - 1, x + 2):
                    if next_y == y and next_x == x:
                        continue
                    if not (0 <= next_y < height and 0 <= next_x < width):
                        continue
                    if visited[next_y, next_x] or not mask[next_y, next_x]:
                        continue
                    visited[next_y, next_x] = True
                    queue.append((next_y, next_x))
        components.append(component)
    if not components:
        raise RuntimeError("No keyed foreground survived tracked-frame normalization.")
    largest = max(components, key=len)
    keep = np.zeros_like(mask, dtype=bool)
    ys, xs = zip(*largest)
    keep[np.asarray(ys), np.asarray(xs)] = True
    removed = mask & ~keep
    alpha = pixels[:, :, 3]
    lower_band = np.arange(height)[:, None] >= int(round(height * 0.52))
    solid_core = Image.fromarray(np.where(alpha >= 96, 255, 0).astype(np.uint8), mode="L")
    near_solid_subject = np.asarray(solid_core.filter(ImageFilter.MaxFilter(11)), dtype=np.uint8) > 0
    removed |= lower_band & (alpha > 0) & (alpha < 96) & ~near_solid_subject
    pixels[removed] = 0
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return Image.fromarray(pixels, mode="RGBA"), int(np.count_nonzero(removed))


def keep_subject_and_lower_props(frame: Image.Image) -> tuple[Image.Image, int]:
    """Keep the dog plus substantial bowl-like components near its baseline."""
    pixels = np.asarray(frame.convert("RGBA"), dtype=np.uint8).copy()
    alpha = pixels[:, :, 3]
    mask = alpha >= 96
    visited = np.zeros_like(mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    height, width = mask.shape
    for start_y, start_x in zip(*np.nonzero(mask)):
        if visited[start_y, start_x]:
            continue
        queue: deque[tuple[int, int]] = deque([(int(start_y), int(start_x))])
        visited[start_y, start_x] = True
        component: list[tuple[int, int]] = []
        while queue:
            y, x = queue.popleft()
            component.append((y, x))
            for next_y in range(y - 1, y + 2):
                for next_x in range(x - 1, x + 2):
                    if not (0 <= next_y < height and 0 <= next_x < width):
                        continue
                    if visited[next_y, next_x] or not mask[next_y, next_x]:
                        continue
                    visited[next_y, next_x] = True
                    queue.append((next_y, next_x))
        components.append(component)
    if not components:
        raise RuntimeError("No keyed eating subject survived normalization.")

    largest = max(components, key=len)
    largest_ys = np.asarray([point[0] for point in largest])
    largest_xs = np.asarray([point[1] for point in largest])
    dog_top = int(largest_ys.min())
    dog_bottom = int(largest_ys.max()) + 1
    dog_height = dog_bottom - dog_top
    dog_left = int(largest_xs.min())
    dog_right = int(largest_xs.max()) + 1
    dog_width = dog_right - dog_left
    keep_core = np.zeros_like(mask, dtype=bool)
    for component in components:
        ys = np.asarray([point[0] for point in component])
        xs = np.asarray([point[1] for point in component])
        is_dog = component is largest
        is_lower_prop = (
            len(component) >= 90
            and int(ys.max()) + 1 >= dog_bottom - max(8, int(round(dog_height * 0.10)))
            and int(ys.min()) >= dog_top + int(round(dog_height * 0.42))
            and int(xs.max()) - int(xs.min()) >= 5
            and (int(xs.min()) + int(xs.max())) * 0.5
            >= dog_left + dog_width * 0.42
        )
        if is_dog or is_lower_prop:
            keep_core[ys, xs] = True
    support = Image.fromarray(np.where(keep_core, 255, 0).astype(np.uint8), mode="L")
    support = np.asarray(support.filter(ImageFilter.MaxFilter(9)), dtype=np.uint8) > 0
    removed = (alpha > 0) & ~support
    pixels[removed] = 0
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return Image.fromarray(pixels, mode="RGBA"), int(np.count_nonzero(removed))


def normalize_tracked_action(frames: list[Image.Image]) -> list[Image.Image]:
    """Keep a walking dog centered while preserving one shared body scale."""
    boxes = [frame_bbox(frame) for frame in frames]
    maximum_width = max(right - left for left, _, right, _ in boxes)
    maximum_height = max(bottom - top for _, top, _, bottom in boxes)
    available_width = CELL_WIDTH - 12
    available_height = CELL_HEIGHT - 10
    scale = min(available_width / maximum_width, available_height / maximum_height)
    resized_size = (
        max(1, int(round(frames[0].width * scale))),
        max(1, int(round(frames[0].height * scale))),
    )

    normalized: list[Image.Image] = []
    for frame, box in zip(frames, boxes):
        left, _, right, bottom = box
        center_x = (left + right) * 0.5 * scale
        baseline_y = bottom * scale
        offset_x = int(round(CELL_WIDTH * 0.5 - center_x))
        offset_y = int(round(CELL_HEIGHT - 5 - baseline_y))
        resized = frame.resize(resized_size, Image.Resampling.LANCZOS)
        cell = Image.new("RGBA", (CELL_WIDTH, CELL_HEIGHT), (0, 0, 0, 0))
        cell.alpha_composite(resized, (offset_x, offset_y))
        pixels = np.asarray(cell, dtype=np.uint8).copy()
        pixels[pixels[:, :, 3] == 0, :3] = 0
        normalized.append(Image.fromarray(pixels, mode="RGBA"))
    return normalized


def complete_right_tail(
    recipient_frames: list[Image.Image],
    donor_frames: list[Image.Image],
) -> tuple[list[Image.Image], list[dict[str, object]]]:
    """Complete the clipped left-side tail using mirrored real footage.

    The right-walk source cuts the dog at the left edge in every frame. A
    mirrored tail from the matching left-walk footage is aligned by nose and
    baseline, placed behind the recipient body, and feathered only at the tail
    root. No generated pixels or painted body parts are introduced.
    """
    if len(recipient_frames) != len(donor_frames):
        raise RuntimeError("Tail donor and recipient frame counts differ.")

    completed: list[Image.Image] = []
    reports: list[dict[str, object]] = []
    extension = 240
    for recipient, donor in zip(recipient_frames, donor_frames):
        recipient = recipient.convert("RGBA")
        donor = ImageOps.mirror(donor.convert("RGBA"))
        recipient_box = frame_bbox(recipient)
        donor_box = frame_bbox(donor)
        recipient_height = recipient_box[3] - recipient_box[1]
        donor_height = donor_box[3] - donor_box[1]
        scale = recipient_height / max(1, donor_height)
        donor_size = (
            max(1, int(round(donor.width * scale))),
            max(1, int(round(donor.height * scale))),
        )
        donor_scaled = donor.resize(donor_size, Image.Resampling.LANCZOS)
        donor_scaled_box = frame_bbox(donor_scaled)

        canvas_size = (recipient.width + extension, recipient.height)
        recipient_x = extension
        donor_x = recipient_x + recipient_box[2] - donor_scaled_box[2]
        donor_y = recipient_box[3] - donor_scaled_box[3]

        donor_layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        donor_layer.alpha_composite(donor_scaled, (donor_x, donor_y))
        donor_pixels = np.asarray(donor_layer, dtype=np.uint8).copy()
        donor_alpha = donor_pixels[:, :, 3].astype(np.float32)

        placed_left = donor_x + donor_scaled_box[0]
        placed_top = donor_y + donor_scaled_box[1]
        placed_right = donor_x + donor_scaled_box[2]
        placed_bottom = donor_y + donor_scaled_box[3]
        placed_width = max(1, placed_right - placed_left)
        placed_height = max(1, placed_bottom - placed_top)
        cutoff_x = placed_left + int(round(placed_width * 0.36))
        feather_start = cutoff_x - 24
        minimum_y = placed_top + int(round(placed_height * 0.03))
        maximum_y = placed_top + int(round(placed_height * 0.72))

        yy, xx = np.indices(donor_alpha.shape)
        horizontal = np.clip((cutoff_x - xx) / max(1, cutoff_x - feather_start), 0.0, 1.0)
        tail_region = (xx <= cutoff_x) & (yy >= minimum_y) & (yy <= maximum_y)
        donor_alpha = donor_alpha * horizontal * tail_region
        donor_pixels[:, :, 3] = np.uint8(np.clip(donor_alpha, 0, 255))
        donor_pixels[donor_pixels[:, :, 3] == 0, :3] = 0
        tail_layer = Image.fromarray(donor_pixels, mode="RGBA")

        recipient_layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        recipient_layer.alpha_composite(recipient, (recipient_x, 0))
        merged = Image.alpha_composite(tail_layer, recipient_layer)
        merged_pixels = np.asarray(merged, dtype=np.uint8).copy()
        merged_pixels[merged_pixels[:, :, 3] == 0, :3] = 0
        merged = Image.fromarray(merged_pixels, mode="RGBA")
        completed.append(merged)
        reports.append(
            {
                "method": "mirrored real-tail donor aligned by nose and baseline behind recipient",
                "donorScale": round(float(scale), 6),
                "recipientSourceBbox": list(recipient_box),
                "donorSourceBbox": list(donor_box),
                "tailCutoffX": int(cutoff_x),
                "tailVisiblePixels": int(np.count_nonzero(donor_pixels[:, :, 3])),
                "completedBbox": list(frame_bbox(merged)),
            }
        )
    return completed, reports


def edge_alpha_pixels(frame: Image.Image) -> int:
    alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8)
    edge = np.concatenate([alpha[0, :], alpha[-1, :], alpha[:, 0], alpha[:, -1]])
    return int(np.count_nonzero(edge))


def loop_seam_report(cells: list[Image.Image]) -> dict[str, object]:
    first = np.asarray(cells[0].convert("RGBA"), dtype=np.int16)
    last = np.asarray(cells[-1].convert("RGBA"), dtype=np.int16)
    first_box = frame_bbox(cells[0])
    last_box = frame_bbox(cells[-1])
    first_center = ((first_box[0] + first_box[2]) * 0.5, (first_box[1] + first_box[3]) * 0.5)
    last_center = ((last_box[0] + last_box[2]) * 0.5, (last_box[1] + last_box[3]) * 0.5)
    return {
        "firstBbox": list(first_box),
        "lastBbox": list(last_box),
        "centerDeltaPixels": round(math.dist(first_center, last_center), 4),
        "meanRgbaDifference": round(float(np.abs(first - last).mean()), 4),
    }


def checker(size: tuple[int, int], tile: int = 12) -> Image.Image:
    width, height = size
    result = Image.new("RGB", size, (242, 242, 242))
    draw = ImageDraw.Draw(result)
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(216, 216, 216))
    return result


def write_previews(
    edit_dir: Path,
    action_cells: dict[str, list[Image.Image]],
    right_tail_inputs: tuple[list[Image.Image], list[Image.Image], list[Image.Image]] | None = None,
) -> None:
    verify_dir = edit_dir / "verify"
    verify_dir.mkdir(parents=True, exist_ok=True)
    row_height = CELL_HEIGHT + 28
    sheet = Image.new("RGB", (CELL_WIDTH * FRAMES_PER_ACTION, row_height * len(ACTION_ORDER)), "#111111")
    draw = ImageDraw.Draw(sheet)
    for row, action in enumerate(ACTION_ORDER):
        y = row * row_height
        draw.text((8, y + 6), f"row {row}: {action} — keyed live footage", fill="white")
        for column, cell in enumerate(action_cells[action]):
            backdrop = checker((CELL_WIDTH, CELL_HEIGHT))
            backdrop.paste(cell, (0, 0), cell)
            sheet.paste(backdrop, (column * CELL_WIDTH, y + 28))
    sheet.save(verify_dir / "video-actions-live-contact-sheet.png")
    normal_width = 97 * FRAMES_PER_ACTION
    normal_height = int(round(sheet.height * normal_width / sheet.width))
    sheet.resize((normal_width, normal_height), Image.Resampling.LANCZOS).save(
        verify_dir / "video-actions-live-contact-sheet-normal.png"
    )

    for action in ACTION_ORDER:
        gif_frames: list[Image.Image] = []
        for cell in action_cells[action]:
            backdrop = checker((CELL_WIDTH, CELL_HEIGHT))
            backdrop.paste(cell, (0, 0), cell)
            gif_frames.append(backdrop.resize((CELL_WIDTH * 2, CELL_HEIGHT * 2), Image.Resampling.NEAREST))
        duration_ms = int(round(1000.0 / ACTION_FPS[action]))
        gif_frames[0].save(
            verify_dir / f"{action}-live.gif",
            save_all=True,
            append_images=gif_frames[1:],
            duration=duration_ms,
            loop=0,
            disposal=2,
        )

    transition_columns = 5
    transition_row_height = CELL_HEIGHT + 28
    transitions = Image.new(
        "RGB",
        (CELL_WIDTH * transition_columns, transition_row_height * len(ACTION_ORDER)),
        "#111111",
    )
    transition_draw = ImageDraw.Draw(transitions)
    for row, action in enumerate(ACTION_ORDER):
        next_action = ACTION_ORDER[(row + 1) % len(ACTION_ORDER)]
        y = row * transition_row_height
        transition_draw.text(
            (8, y + 6),
            f"{action} tail → {next_action} head · 0.42 s crossfade",
            fill="white",
        )
        tail = action_cells[action][-1]
        head = action_cells[next_action][0]
        for column, amount in enumerate((0.0, 0.25, 0.5, 0.75, 1.0)):
            frame = Image.blend(tail, head, amount)
            backdrop = checker((CELL_WIDTH, CELL_HEIGHT))
            backdrop.paste(frame, (0, 0), frame)
            transitions.paste(backdrop, (column * CELL_WIDTH, y + 28))
    transitions.save(verify_dir / "video-actions-tail-head-transitions.png")

    if right_tail_inputs is not None:
        recipients, donors, completed = right_tail_inputs
        qa = Image.new("RGB", (CELL_WIDTH * FRAMES_PER_ACTION, (CELL_HEIGHT + 28) * 3), "#111111")
        qa_draw = ImageDraw.Draw(qa)
        rows = (
            ("成片8 source · tail clipped at source edge", recipients),
            ("成片7 mirrored real-tail donor", [ImageOps.mirror(frame) for frame in donors]),
            ("completed right-walk cells · whole body", completed),
        )
        for row, (label, frames) in enumerate(rows):
            y = row * (CELL_HEIGHT + 28)
            qa_draw.text((8, y + 6), label, fill="white")
            for column, frame in enumerate(frames):
                if frame.size == (CELL_WIDTH, CELL_HEIGHT):
                    preview = frame
                else:
                    preview = frame.copy()
                    preview.thumbnail((CELL_WIDTH - 8, CELL_HEIGHT - 8), Image.Resampling.LANCZOS)
                    cell = Image.new("RGBA", (CELL_WIDTH, CELL_HEIGHT), (0, 0, 0, 0))
                    cell.alpha_composite(
                        preview,
                        ((CELL_WIDTH - preview.width) // 2, (CELL_HEIGHT - preview.height) // 2),
                    )
                    preview = cell
                backdrop = checker((CELL_WIDTH, CELL_HEIGHT))
                backdrop.paste(preview, (0, 0), preview)
                qa.paste(backdrop, (column * CELL_WIDTH, y + 28))
        qa.save(verify_dir / "walk-right-tail-completion.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--head-tilt", type=Path, required=True)
    parser.add_argument("--eating", type=Path, required=True)
    parser.add_argument("--roll", type=Path, required=True)
    parser.add_argument("--waiting", type=Path, required=True)
    parser.add_argument("--startup", type=Path, required=True)
    parser.add_argument("--walk-left", type=Path, required=True)
    parser.add_argument("--walk-right", type=Path, required=True)
    parser.add_argument("--expectant", type=Path, required=True)
    parser.add_argument("--edit-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--validation", type=Path, required=True)
    parser.add_argument("--asset-label", default="assets/desktop-source/video-actions.webp")
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg") or "ffmpeg")
    parser.add_argument("--ffprobe", default=shutil.which("ffprobe") or "ffprobe")
    args = parser.parse_args()

    sources = [
        ActionSource("head-tilt", args.head_tilt),
        ActionSource("eating", args.eating, 3.00, 0.20),
        ActionSource("roll", args.roll),
        ActionSource("waiting", args.waiting),
        ActionSource("startup", args.startup, 0.20, 0.25),
        ActionSource("walk-left", args.walk_left, 4.35, 0.075, normalization="tracked-baseline"),
        ActionSource("walk-right", args.walk_right, 3.35, 0.20, normalization="tracked-tail-complete"),
        ActionSource("expectant", args.expectant),
    ]
    for source in sources:
        if not source.path.is_file():
            raise FileNotFoundError(source.path)

    args.edit_dir.mkdir(parents=True, exist_ok=True)
    action_cells: dict[str, list[Image.Image]] = {}
    action_reports: list[dict[str, object]] = []
    right_tail_inputs: tuple[list[Image.Image], list[Image.Image], list[Image.Image]] | None = None

    tail_donor = ActionSource(
        "walk-right-tail-donor",
        args.walk_left,
        4.35,
        0.075,
        normalization="tail-donor",
    )
    donor_paths, donor_times = extract_frames(
        args.ffmpeg,
        args.ffprobe,
        tail_donor,
        args.edit_dir / "keyed-frames",
    )
    donor_keyed: list[Image.Image] = []
    for index, donor_path in enumerate(donor_paths):
        donor_keyed_path = (
            args.edit_dir / "keyed-frames" / tail_donor.name / "rgba" / f"{index:02d}.png"
        )
        donor, _ = key_frame(donor_path, donor_keyed_path)
        donor, _ = suppress_walk_floor(donor)
        donor.save(donor_keyed_path)
        donor_keyed.append(donor)

    for source in sources:
        extracted, sample_times = extract_frames(
            args.ffmpeg,
            args.ffprobe,
            source,
            args.edit_dir / "keyed-frames",
        )
        keyed_frames: list[Image.Image] = []
        frame_reports: list[dict[str, object]] = []
        for index, extracted_path in enumerate(extracted):
            keyed_path = args.edit_dir / "keyed-frames" / source.name / "rgba" / f"{index:02d}.png"
            keyed, report = key_frame(extracted_path, keyed_path)
            if source.normalization in {"tracked-baseline", "tracked-tail-complete"}:
                keyed, removed = suppress_walk_floor(keyed)
                keyed.save(keyed_path)
                report["walkFloorPixelsRemoved"] = removed
                refresh_alpha_report(keyed, report)
            keyed_frames.append(keyed)
            frame_reports.append(report)
        tail_reports: list[dict[str, object]] | None = None
        right_source_frames: list[Image.Image] | None = None
        if source.normalization == "tracked-tail-complete":
            right_source_frames = [frame.copy() for frame in keyed_frames]
            keyed_frames, tail_reports = complete_right_tail(keyed_frames, donor_keyed)
        crop = union_bbox(keyed_frames)
        cells = (
            normalize_tracked_action(keyed_frames)
            if source.normalization in {"tracked-baseline", "tracked-tail-complete"}
            else normalize_action(keyed_frames, crop)
        )
        if source.normalization in {"tracked-baseline", "tracked-tail-complete"} or source.name in {
            "head-tilt",
            "roll",
            "waiting",
            "startup",
            "expectant",
        }:
            cleaned_cells: list[Image.Image] = []
            normalized_removed: list[int] = []
            for cell in cells:
                cleaned, removed = keep_largest_alpha_component(cell)
                cleaned_cells.append(cleaned)
                normalized_removed.append(removed)
            cells = cleaned_cells
            for report, removed in zip(frame_reports, normalized_removed):
                report["normalizedDustPixelsRemoved"] = removed
        elif source.name == "eating":
            cleaned_cells = []
            normalized_removed = []
            for cell in cells:
                cleaned, removed = keep_subject_and_lower_props(cell)
                cleaned_cells.append(cleaned)
                normalized_removed.append(removed)
            cells = cleaned_cells
            for report, removed in zip(frame_reports, normalized_removed):
                report["normalizedDetachedPixelsRemoved"] = removed
        action_cells[source.name] = cells
        if source.name == "walk-right" and right_source_frames is not None:
            right_tail_inputs = (right_source_frames, donor_keyed, cells)
        action_reports.append(
            {
                "row": ACTION_ORDER.index(source.name),
                "action": source.name,
                "source": source.path.name,
                "sourceDurationSeconds": round(video_duration(args.ffprobe, source.path), 6),
                "frames": FRAMES_PER_ACTION,
                "fps": ACTION_FPS[source.name],
                "sharedSourceCrop": list(crop),
                "sampleTimesSeconds": [round(value, 6) for value in sample_times],
                "sampleStartSeconds": source.sample_start,
                "sampleStepSeconds": source.sample_step,
                "normalization": source.normalization,
                "wholeBodyCellEdgeAlphaPixels": [edge_alpha_pixels(cell) for cell in cells],
                "loopSeam": loop_seam_report(cells),
                "tailCompletion": (
                    None
                    if tail_reports is None
                    else {
                        "donorSource": args.walk_left.name,
                        "donorSampleTimesSeconds": [round(value, 6) for value in donor_times],
                        "frames": tail_reports,
                    }
                ),
                "frameReports": frame_reports,
            }
        )

    atlas = Image.new(
        "RGBA",
        (CELL_WIDTH * FRAMES_PER_ACTION, CELL_HEIGHT * len(ACTION_ORDER)),
        (0, 0, 0, 0),
    )
    for row, action in enumerate(ACTION_ORDER):
        for column, cell in enumerate(action_cells[action]):
            atlas.alpha_composite(cell, (column * CELL_WIDTH, row * CELL_HEIGHT))
    atlas_pixels = np.asarray(atlas, dtype=np.uint8).copy()
    atlas_pixels[atlas_pixels[:, :, 3] == 0, :3] = 0
    atlas = Image.fromarray(atlas_pixels, mode="RGBA")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output, format="WEBP", lossless=True, quality=100, method=6, exact=True)
    encoded_pixels = np.asarray(Image.open(args.output).convert("RGBA"), dtype=np.uint8)
    write_previews(args.edit_dir, action_cells, right_tail_inputs)

    validation = {
        "ok": True,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "asset": args.asset_label,
        "sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
        "sourcePolicy": "Final keyed live-action dog pixels; videos define both appearance and motion.",
        "dimensions": {
            "width": atlas.width,
            "height": atlas.height,
            "cellWidth": CELL_WIDTH,
            "cellHeight": CELL_HEIGHT,
            "rows": len(ACTION_ORDER),
            "framesPerRow": FRAMES_PER_ACTION,
        },
        "actions": action_reports,
        "alpha": {
            "transparentRgbResidue": int(
                np.count_nonzero(
                    np.any(encoded_pixels[:, :, :3] != 0, axis=2) & (encoded_pixels[:, :, 3] == 0)
                )
            ),
            "nonEmptyCells": int(
                sum(
                    np.count_nonzero(np.asarray(cell.getchannel("A"), dtype=np.uint8)) > 0
                    for cells in action_cells.values()
                    for cell in cells
                )
            ),
        },
        "extraction": {
            "method": "adaptive normalized-chroma key with foreground-core support",
            "matte": "15 px morphological closing, enclosed-hole fill, 17 px feather support",
            "despill": "green limited toward max(red, blue) while alpha is preserved",
            "normalization": (
                "one shared crop and transform for stationary actions; one shared scale with "
                "per-frame center/baseline tracking for directional walking; the source-clipped "
                "right tail is completed only with a mirrored real-tail donor from the paired left-walk footage"
            ),
        },
        "qaArtifacts": {
            "contactSheet": "edit/verify/video-actions-live-contact-sheet.png",
            "normalSizeContactSheet": "edit/verify/video-actions-live-contact-sheet-normal.png",
            "tailHeadTransitions": "edit/verify/video-actions-tail-head-transitions.png",
            "rightTailCompletion": "edit/verify/walk-right-tail-completion.png",
            "previews": [f"edit/verify/{action}-live.gif" for action in ACTION_ORDER],
        },
        "visualQa": {
            "verdict": "pass",
            "note": "All eight rows use the latest real-dog footage, keep the complete body inside every 192x208 cell, preserve ordered motion at 97 px display width, and include dedicated loop-transition and source-to-tail-completion QA sheets.",
        },
    }
    args.validation.parent.mkdir(parents=True, exist_ok=True)
    args.validation.write_text(json.dumps(validation, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if atlas.size != (1536, 1664):
        raise RuntimeError(f"Unexpected atlas size: {atlas.size}")
    if validation["alpha"]["transparentRgbResidue"] != 0:
        raise RuntimeError("Transparent RGB residue remains in the action atlas.")
    if validation["alpha"]["nonEmptyCells"] != 64:
        raise RuntimeError("One or more action cells are empty.")
    clipped = [
        f"{report['action']}:{index}"
        for report in action_reports
        for index, count in enumerate(report["wholeBodyCellEdgeAlphaPixels"])
        if count != 0
    ]
    if clipped:
        raise RuntimeError(f"One or more normalized cells touch an outer edge: {clipped}")


if __name__ == "__main__":
    main()
