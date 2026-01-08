import { Router } from "express";
import {
  createUser,
  getUsers,
  getUserByUid,
  updateUser,
  deleteUser,
  getSalonsNearby,
  registerUserComplete,
  updateFCMToken,
  deleteFCMToken,
  sendVerificationCode,
  verifyCode,
} from "../controllers/user.controller";
import { validateProfileImage } from '../middleware/image-validator.middleware';

const router = Router();
router.post("/", createUser);
router.get("/", getUsers);
router.post('/register', registerUserComplete);
router.get("/uid/:uid", getUserByUid);
router.put("/:uid", validateProfileImage, updateUser);
router.delete("/:uid", deleteUser);
router.get("/salons/nearby", getSalonsNearby);

// FCM Token routes
router.put("/fcm-token", updateFCMToken);
router.delete("/fcm-token", deleteFCMToken);

// Email verification routes
router.post("/send-verification-code", sendVerificationCode);
router.post("/verify-code", verifyCode);

export default router;
